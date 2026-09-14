"""
integration.py
This is the file that actually connects the three teammates' pieces:

    backend        -> nothing to do here, just calls run_full_analysis()
    decision_engine -> the "brain" (engine/ package)
    forecast_new    -> the ML models (ml/ package)

Flow for one uploaded workbook:

  1. Read the "BusinessData" sheet with the decision engine's own Excel
     loader -> a BusinessState (cash, obligations, receivables, actions).
  2. If a "Sales" sheet is present and has enough history, train + run
     the sales forecast model (30 days ahead).
  3. If an "Udhar" sheet is present and has enough payment history,
     train + run the udhaar (customer credit) payment-behavior model.
  4. THE KEY STEP: for every receivable in the BusinessState whose name
     matches a Customer_ID the udhaar model made a prediction for,
     overwrite that receivable's reliability_score with a score derived
     from the ML prediction (see udhar_prediction_to_reliability below).
     This is what makes the decision engine "automatically trust that
     money less" when the ML model expects a customer to pay late.
  5. Run the decision engine's recommend() on the (now ML-adjusted)
     BusinessState.
  6. Also build the combined sales+collections cash forecast from
     forecast_new's cash_forecast.py, purely as extra context for the
     dashboard (it does not feed back into the optimizer - see README
     for why that boundary was kept explicit).

Any step that can't run (sheet missing, not enough history yet) is
skipped, not treated as a hard failure - a brand new business with no
Udhar sheet at all should still get a full cash-allocation
recommendation, just without the ML risk-adjustment on top of it.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

import openpyxl
import numpy as np
import pandas as pd

from engine.excel_loader import load_business_state_from_excel, ExcelFormatError
from engine.models import InvalidBusinessStateError
from engine.optimizer import recommend

from ml.sales_forecast import train_sales_model, forecast_sales
from ml.udhar_model import train_udhar_model, predict_customers
from ml.cash_forecast import create_cash_forecast

BUSINESS_SHEET_NAME = "BusinessData"
SALES_SHEET_NAME = "Sales"
UDHAR_SHEET_NAME = "Udhar"

MIN_SALES_ROWS = 60      # sales_forecast.train_sales_model's own minimum
MIN_UDHAR_TRAINING_ROWS = 10  # udhar_model.train_udhar_model's own minimum


def _json_safe(value: Any) -> Any:
    """Converts pandas/numpy types (Timestamp, numpy.float64, NaN, ...)
    coming out of the ML dataframes into plain JSON-serializable Python
    types, so results can go straight into a JSON HTTP response and a
    SQLAlchemy JSON database column without extra handling everywhere
    else in the codebase."""
    if isinstance(value, (pd.Timestamp,)):
        return value.date().isoformat()
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        f = float(value)
        return None if pd.isna(f) else f
    if isinstance(value, float) and pd.isna(value):
        return None
    return value


def _records_json_safe(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [{k: _json_safe(v) for k, v in row.items()} for row in records]


def _sheet_names(path: str) -> List[str]:
    wb = openpyxl.load_workbook(path, read_only=True)
    try:
        return wb.sheetnames
    finally:
        wb.close()


def udhar_prediction_to_reliability(predicted_behavior: str, confidence_pct: float) -> float:
    """
    Turns one ML prediction (label + confidence, 0-100) into the 0-1
    reliability_score the decision engine's Receivable already knows how
    to use (see models.Receivable.compute_reliability_score - an
    explicit reliability_score always overrides payment_history).

    Deliberately simple and transparent, matching the engine's own
    "every score must be explainable in one sentence" design:

      EARLY / ON TIME predictions -> reliability rises from 0.5 (a coin
      flip) towards 1.0 as the model's confidence rises towards 100%.

      LATE predictions -> reliability falls from 0.5 towards 0.1 as
      confidence rises - never all the way to 0, because even a
      confident "late" prediction is still a prediction, not a
      certainty, and a small amount of the receivable is still safe to
      count.
    """
    confidence = max(0.0, min(100.0, confidence_pct)) / 100.0
    label = (predicted_behavior or "").strip().upper()

    if label in ("EARLY", "ON TIME"):
        return round(0.5 + 0.5 * confidence, 3)
    if label == "LATE":
        return round(0.5 - 0.4 * confidence, 3)
    # Unrecognized label (shouldn't happen) - stay neutral.
    return 0.5


def _run_sales_forecast(path: str) -> Tuple[Optional[List[Dict[str, Any]]], Optional[str]]:
    try:
        train_sales_model(path)
        df = forecast_sales(path, days=30)
        return _records_json_safe(df.to_dict(orient="records")), None
    except Exception as e:  # noqa: BLE001 - any ML/data problem just disables this feature
        return None, f"Sales forecast skipped: {e}"


def _run_udhar_model(path: str) -> Tuple[Optional[List[Dict[str, Any]]], Optional[str]]:
    try:
        train_udhar_model(path)
        df = predict_customers(path)
        if df.empty:
            return None, "Udhar model trained, but there was no recent payment history to score."
        return _records_json_safe(df.to_dict(orient="records")), None
    except Exception as e:  # noqa: BLE001
        return None, f"Udhar (customer credit) risk model skipped: {e}"


def _run_cash_forecast(path: str) -> Tuple[Optional[List[Dict[str, Any]]], Optional[str]]:
    try:
        df = create_cash_forecast(path, days=30)
        return _records_json_safe(df.to_dict(orient="records")), None
    except Exception as e:  # noqa: BLE001
        return None, f"Combined cash forecast skipped: {e}"


def _apply_udhar_predictions_to_receivables(state, udhar_predictions: List[Dict[str, Any]]) -> List[str]:
    """Mutates state.receivables in place, matching each Receivable's
    `description` against the ML model's Customer_ID (case-insensitive,
    whitespace-trimmed - the two sheets are expected to use the exact
    same customer name/ID in both places; see README).

    Returns a list of human-readable notes about what was adjusted, for
    the response's "why" trail.
    """
    notes: List[str] = []
    by_customer = {
        str(row["Customer_ID"]).strip().lower(): row for row in udhar_predictions
    }
    for r in state.receivables:
        key = r.description.strip().lower()
        row = by_customer.get(key)
        if not row:
            continue
        old_score = r.compute_reliability_score()
        new_score = udhar_prediction_to_reliability(row["Predicted_Behavior"], row["Confidence"])
        r.reliability_score = new_score
        notes.append(
            f"'{r.description}': ML predicts {row['Predicted_Behavior']} "
            f"({row['Confidence']:.0f}% confidence) -> reliability adjusted "
            f"{old_score:.2f} -> {new_score:.2f}."
        )
    return notes


def run_full_analysis(path: str) -> Dict[str, Any]:
    """Main entry point used by main.py's /analyze endpoint.

    Returns a dict with:
        business        - meta fields for the dashboard header
        recommendation  - the decision engine's full output (ML-adjusted)
        sales_forecast   - list of {Date, Predicted_Sales} or None
        udhar_predictions - list of per-customer predictions or None
        cash_forecast    - combined sales+collections forecast or None
        ml_notes         - what ran, what was skipped and why, what was
                           adjusted because of the ML predictions
    """
    sheets = _sheet_names(path)
    ml_notes: List[str] = []

    # --- Step 1: business state (the decision engine's own job) -----------
    try:
        state, meta = load_business_state_from_excel(path, sheet_name=BUSINESS_SHEET_NAME)
    except (ExcelFormatError, InvalidBusinessStateError):
        raise  # let the caller turn this into a clean 400

    # --- Step 2: sales forecast (informational, does not feed the optimizer) ---
    sales_forecast = None
    if SALES_SHEET_NAME in sheets:
        sales_forecast, note = _run_sales_forecast(path)
        if note:
            ml_notes.append(note)
    else:
        ml_notes.append(f"No '{SALES_SHEET_NAME}' sheet found - sales forecast not generated.")

    # --- Step 3: udhaar payment-behavior model -----------------------------
    udhar_predictions = None
    if UDHAR_SHEET_NAME in sheets:
        udhar_predictions, note = _run_udhar_model(path)
        if note:
            ml_notes.append(note)
    else:
        ml_notes.append(f"No '{UDHAR_SHEET_NAME}' sheet found - udhaar risk model not run; "
                         f"receivables use the Payment_History given in the {BUSINESS_SHEET_NAME} sheet, if any.")

    # --- Step 4: THE INTEGRATION - feed ML predictions into the engine -----
    if udhar_predictions:
        adjustment_notes = _apply_udhar_predictions_to_receivables(state, udhar_predictions)
        ml_notes.extend(adjustment_notes)

    # --- Step 5: combined cash forecast (sales + expected collections) -----
    cash_forecast = None
    if SALES_SHEET_NAME in sheets and UDHAR_SHEET_NAME in sheets:
        cash_forecast, note = _run_cash_forecast(path)
        if note:
            ml_notes.append(note)

    # --- Step 6: run the decision engine on the (ML-adjusted) state --------
    recommendation = recommend(state)

    return {
        "business": {
            "business_name": meta.business_name,
            "business_type": meta.business_type,
            "location": meta.location,
            "reporting_date": meta.reporting_date,
            "monthly_sales": meta.monthly_sales,
            "monthly_expenses": meta.monthly_expenses,
        },
        "cash_breakdown": {
            "cash": state.cash,
            "total_obligations": state.total_obligations(),
            "reserve": state.reserve,
            "risk_buffer": state.risk_buffer,
        },
        "obligations": [
            {"name": o.name, "amount": o.amount, "days_until_due": o.days_until_due}
            for o in state.obligations
        ],
        "recommendation": recommendation,
        "sales_forecast": sales_forecast,
        "udhar_predictions": udhar_predictions,
        "cash_forecast": cash_forecast,
        "ml_notes": ml_notes,
        "raw_state": {
            "cash": state.cash,
            "reserve": state.reserve,
            "risk_buffer": state.risk_buffer,
            "obligations": [
                {"name": o.name, "amount": o.amount, "days_until_due": o.days_until_due}
                for o in state.obligations
            ],
            "receivables": [
                {
                    "description": r.description, "amount": r.amount,
                    "days_until_expected": r.days_until_expected,
                    "payment_history": r.payment_history, "reliability_score": r.reliability_score,
                }
                for r in state.receivables
            ],
            "actions": [
                {
                    "name": a.name, "max_amount": a.max_amount,
                    "benefit_score": a.benefit_score, "risk_score": a.risk_score,
                    "min_amount": a.min_amount, "step": a.step,
                }
                for a in state.actions
            ],
        },
    }


def rebuild_state_from_raw(raw_state: Dict[str, Any]):
    """Rebuilds a BusinessState from an Analysis row's stored raw_state
    JSON, so /evaluate-spend and /simulate can re-run the engine against
    a past upload without asking the user to re-upload the file."""
    from engine.models import BusinessState, Obligation, Receivable, Action

    return BusinessState(
        cash=raw_state["cash"],
        reserve=raw_state["reserve"],
        risk_buffer=raw_state.get("risk_buffer", 0.0),
        obligations=[Obligation(**o) for o in raw_state.get("obligations", [])],
        receivables=[Receivable(**r) for r in raw_state.get("receivables", [])],
        actions=[Action(**a) for a in raw_state.get("actions", [])],
    )
