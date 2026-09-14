from pydantic import BaseModel


# ==========================================
# AUTHENTICATION
# ==========================================

class SignupRequest(BaseModel):
    name: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


# ==========================================
# SPEND / SIMULATE (re-run against a saved analysis)
# ==========================================

class ProposedAmountRequest(BaseModel):
    proposed_amount: float


class SimulateRequest(BaseModel):
    proposed_amount: float
    horizon_days: int = 30
