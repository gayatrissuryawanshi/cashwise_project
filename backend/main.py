"""
main.py
The ONE combined backend.

    /signup, /login              -> Person 1's auth system, unchanged
    /analyze                     -> upload one Excel workbook, get back:
                                       - the decision engine's full
                                         recommendation (Person 3's "brain"),
                                         with receivables risk-adjusted
                                         using Person 2's ML predictions
                                       - the raw ML outputs too (sales
                                         forecast, udhaar predictions)
                                     saved to ONE clean database table.
    /analyses, /analyses/{id}    -> list / reopen past uploads
    /evaluate-spend, /simulate   -> re-run "can I spend X?" / "what if I
                                     spend X?" against a past upload,
                                     without re-uploading the file

Run it:
    uvicorn main:app --reload --port 8000
"""

import os
import tempfile
from datetime import datetime

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import SessionLocal, Base, engine
from db_models import User, Analysis
from schemas import SignupRequest, LoginRequest, ProposedAmountRequest, SimulateRequest
from auth import hash_password, verify_password, create_access_token, decode_access_token

from engine.models import InvalidBusinessStateError
from engine.excel_loader import ExcelFormatError
from engine.optimizer import evaluate_proposed_spend
from engine.scenario import simulate_decision

from integration import run_full_analysis, rebuild_state_from_raw


# ==========================================
# APP + DATABASE SETUP
# ==========================================

app = FastAPI(title="CashFlow Engine (combined)", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Creates all tables (users, analyses) on first run - no manual migration
# step needed for SQLite. If you switch to Postgres via DATABASE_URL,
# this still works the same way for a fresh database.
Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ==========================================
# AUTHENTICATION
# ==========================================

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    token = credentials.credentials
    user_id = decode_access_token(token)
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = db.query(User).filter(User.user_id == user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user


# ==========================================
# HOME
# ==========================================

@app.get("/")
def home():
    return {"status": "CashFlow Engine running", "database": str(engine.url)}


# ==========================================
# SIGNUP / LOGIN
# ==========================================

@app.post("/signup")
def signup(data: SignupRequest, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        name=data.name,
        email=data.email,
        password_hash=hash_password(data.password),
        created_at=datetime.now(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"message": "Signup successful", "user_id": user.user_id}


@app.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_access_token(user.user_id)
    return {
        "message": "Login successful",
        "access_token": token,
        "token_type": "bearer",
        "user_id": user.user_id,
    }


# ==========================================
# ANALYZE - the main combined pipeline
# ==========================================

@app.post("/analyze")
async def analyze(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload one Excel workbook (see BUSINESS_DATA_TEMPLATE.xlsx) with up
    to three sheets: BusinessData (required), Sales (optional, enables
    the sales forecast), Udhar (optional, enables the customer
    payment-behavior model that risk-adjusts receivables).

    Runs the full pipeline and saves everything as one Analysis row.
    """
    if not file.filename.lower().endswith((".xlsx", ".xlsm")):
        raise HTTPException(status_code=400, detail="Please upload an .xlsx file.")

    tmp_path = tempfile.mktemp(suffix=".xlsx")
    try:
        with open(tmp_path, "wb") as tmp:
            tmp.write(await file.read())

        try:
            result = run_full_analysis(tmp_path)
        except ExcelFormatError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except InvalidBusinessStateError as e:
            raise HTTPException(status_code=400, detail=str(e))
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    business = result["business"]
    record = Analysis(
        user_id=current_user.user_id,
        business_name=business["business_name"],
        business_type=business["business_type"],
        location=business["location"],
        reporting_date=str(business["reporting_date"]) if business["reporting_date"] else None,
        monthly_sales=str(business["monthly_sales"]) if business["monthly_sales"] is not None else None,
        monthly_expenses=str(business["monthly_expenses"]) if business["monthly_expenses"] is not None else None,
        raw_state=result["raw_state"],
        sales_forecast=result["sales_forecast"],
        udhar_predictions=result["udhar_predictions"],
        cash_forecast=result["cash_forecast"],
        recommendation=result["recommendation"],
        ml_notes=result["ml_notes"],
        created_at=datetime.now(),
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    result["analysis_id"] = record.analysis_id
    return result


# ==========================================
# LIST / REOPEN PAST ANALYSES
# ==========================================

@app.get("/analyses")
def list_analyses(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    records = (
        db.query(Analysis)
        .filter(Analysis.user_id == current_user.user_id)
        .order_by(Analysis.analysis_id.desc())
        .all()
    )
    return [
        {
            "analysis_id": r.analysis_id,
            "business_name": r.business_name,
            "created_at": r.created_at,
            "safe_to_deploy": (r.recommendation or {}).get("safe_to_deploy"),
            "risk_level": (r.recommendation or {}).get("risk_level"),
        }
        for r in records
    ]


def _get_owned_analysis(analysis_id: int, db: Session, current_user: User) -> Analysis:
    record = (
        db.query(Analysis)
        .filter(Analysis.analysis_id == analysis_id, Analysis.user_id == current_user.user_id)
        .first()
    )
    if not record:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return record


@app.get("/analyses/latest")
def latest_analysis(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    record = (
        db.query(Analysis)
        .filter(Analysis.user_id == current_user.user_id)
        .order_by(Analysis.analysis_id.desc())
        .first()
    )
    if not record:
        raise HTTPException(status_code=404, detail="No analyses yet - upload an Excel file first via /analyze")
    return _analysis_to_dict(record)


@app.get("/analyses/{analysis_id}")
def get_analysis(analysis_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    record = _get_owned_analysis(analysis_id, db, current_user)
    return _analysis_to_dict(record)


def _analysis_to_dict(r: Analysis) -> dict:
    return {
        "analysis_id": r.analysis_id,
        "business_name": r.business_name,
        "business_type": r.business_type,
        "location": r.location,
        "reporting_date": r.reporting_date,
        "monthly_sales": r.monthly_sales,
        "monthly_expenses": r.monthly_expenses,
        "recommendation": r.recommendation,
        "sales_forecast": r.sales_forecast,
        "udhar_predictions": r.udhar_predictions,
        "cash_forecast": r.cash_forecast,
        "ml_notes": r.ml_notes,
        "created_at": r.created_at,
    }


# ==========================================
# RE-RUN "CAN I SPEND X?" / "WHAT IF I SPEND X?"
# against a past upload, no re-upload needed
# ==========================================

@app.post("/analyses/{analysis_id}/evaluate-spend")
def evaluate_spend_for_analysis(
    analysis_id: int,
    payload: ProposedAmountRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = _get_owned_analysis(analysis_id, db, current_user)
    try:
        state = rebuild_state_from_raw(record.raw_state)
        return evaluate_proposed_spend(state, payload.proposed_amount)
    except InvalidBusinessStateError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/analyses/{analysis_id}/simulate")
def simulate_for_analysis(
    analysis_id: int,
    payload: SimulateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = _get_owned_analysis(analysis_id, db, current_user)
    try:
        state = rebuild_state_from_raw(record.raw_state)
        if payload.horizon_days <= 0:
            raise InvalidBusinessStateError(f"horizon_days must be positive, got {payload.horizon_days}.")
        return simulate_decision(state, payload.proposed_amount, payload.horizon_days)
    except InvalidBusinessStateError as e:
        raise HTTPException(status_code=400, detail=str(e))
