"""
db_models.py
The ONE clean set of database tables for the combined app, replacing
the three separate/mismatched formats each teammate's piece used on
its own (backend's Postgres tables, decision engine's in-memory-only
state, forecast_new's loose CSV/pickle files).

USERS               - login/signup (from Person 1's backend)
ANALYSIS            - one row per Excel upload: the parsed business
                      state, the ML outputs (sales forecast + udhaar
                      predictions), and the final decision-engine
                      recommendation, all together so a user's history
                      of uploads can be listed/reopened later.
"""

from sqlalchemy import Column, Integer, String, DateTime, JSON, ForeignKey
from sqlalchemy.orm import relationship

from database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime)

    analyses = relationship("Analysis", back_populates="user")


class Analysis(Base):
    """One full result of 'upload an Excel -> get a recommendation'.

    raw_state: the parsed BusinessState (cash/obligations/receivables/
    actions) as plain JSON, kept so a later /evaluate-spend or /simulate
    call can rebuild the same BusinessState without re-uploading the
    file.

    sales_forecast / udhar_predictions: the ML outputs, or null if that
    sheet was missing or didn't have enough history to train on.

    recommendation: the decision engine's full output (safe_to_deploy,
    allocation, why, risk, fragility, counterfactuals, receivables_risk)
    - already ML-adjusted, since udhar predictions are merged into the
    receivables' reliability scores before this is computed.
    """

    __tablename__ = "analyses"

    analysis_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)

    business_name = Column(String(150))
    business_type = Column(String(100))
    location = Column(String(150))
    reporting_date = Column(String(50))
    monthly_sales = Column(String(50))
    monthly_expenses = Column(String(50))

    raw_state = Column(JSON)
    sales_forecast = Column(JSON)
    udhar_predictions = Column(JSON)
    cash_forecast = Column(JSON)
    recommendation = Column(JSON)

    ml_notes = Column(JSON)  # e.g. why sales/udhar ML was skipped, if it was

    created_at = Column(DateTime)

    user = relationship("User", back_populates="analyses")
