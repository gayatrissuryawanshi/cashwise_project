"""
sample_data.py
"Shree Ganesh Grocery" - the fictional business used across the demo.
Import SAMPLE_BUSINESS wherever you need a quick realistic BusinessState.
"""

from .models import BusinessState, Obligation, Action, Receivable

SAMPLE_BUSINESS = BusinessState(
    cash=250000,
    obligations=[
        Obligation("Salary", 45000, days_until_due=10),
        Obligation("Rent", 20000, days_until_due=15),
        Obligation("GST", 18000, days_until_due=14),
        Obligation("Supplier payment", 55000, days_until_due=20),
    ],
    receivables=[
        # A reliable regular customer - full history of on-time payment,
        # so their udhaar counts at (close to) full face value.
        Receivable(
            amount=45000, days_until_expected=12, description="Ramesh Kirana (regular customer)",
            payment_history=["on_time", "on_time", "on_time"],
        ),
        # A customer who's paid late before and defaulted once - the
        # Udhaar Risk Score discounts this one heavily rather than
        # counting the full ₹25,000 as safe incoming cash.
        Receivable(
            amount=25000, days_until_expected=12, description="Suresh Traders (irregular payer)",
            payment_history=["on_time", "late", "defaulted"],
        ),
    ],
    reserve=50000,
    risk_buffer=20000,
    actions=[
        Action("inventory", max_amount=70000, benefit_score=85, risk_score=30, step=5000),
        Action("supplier_payment", max_amount=55000, benefit_score=65, risk_score=10, step=5000),
        Action("marketing", max_amount=30000, benefit_score=55, risk_score=50, step=5000),
    ],
)

# A "danger" scenario for testing the DON'T SPEND path
LOW_CASH_BUSINESS = BusinessState(
    cash=250000,
    obligations=[
        Obligation("Salary", 45000, days_until_due=5),
        Obligation("Rent", 20000, days_until_due=10),
        Obligation("GST", 18000, days_until_due=7),
        Obligation("Supplier payment", 97000, days_until_due=12),
    ],
    reserve=50000,
    risk_buffer=20000,
    actions=[
        Action("inventory", max_amount=70000, benefit_score=85, risk_score=30, step=5000),
        Action("supplier_payment", max_amount=97000, benefit_score=65, risk_score=10, step=5000),
        Action("marketing", max_amount=30000, benefit_score=55, risk_score=50, step=5000),
    ],
)
