"""
udhaar_risk.py
The "Udhaar Risk Score" feature - Person 3's addition.

The problem it fixes: every version of this engine so far (and every
competing cash-flow app) treats a receivable as guaranteed money that
will arrive in full on the expected date. Indian small businesses extend
informal customer credit (udhaar) constantly, and some customers
reliably pay late or never pay at all. Nobody risk-adjusts for that -
they just track "owed" vs "paid".

This module doesn't change how a Receivable's score is computed (that
logic lives on the Receivable dataclass itself in models.py, next to its
other fields) - it aggregates those per-receivable scores into a single
summary the API/frontend can show directly: how much is on the books at
face value vs. how much is realistically collectible.
"""

from typing import List, Dict, Any
from .models import Receivable


def summarize_receivables_risk(receivables: List[Receivable]) -> Dict[str, Any]:
    """
    Aggregates the Udhaar Risk Score across every receivable on a
    business's books.

    Returns:
        total_face_value     -> sum of every receivable's raw amount
        total_risk_adjusted  -> sum of every receivable's risk_adjusted_amount()
        at_risk_amount       -> the gap between the two - money on the books
                                 that shouldn't be counted on arriving
        receivables          -> per-receivable breakdown, largest at-risk
                                 amount first, so the riskiest udhaar is
                                 the first thing an owner sees
    """
    if not receivables:
        return {
            "total_face_value": 0.0,
            "total_risk_adjusted": 0.0,
            "at_risk_amount": 0.0,
            "receivables": [],
        }

    breakdown = []
    for r in receivables:
        risk_adjusted = r.risk_adjusted_amount()
        breakdown.append({
            "description": r.description,
            "amount": r.amount,
            "days_until_expected": r.days_until_expected,
            "reliability_score": round(r.compute_reliability_score(), 2),
            "reliability_label": r.reliability_label(),
            "risk_adjusted_amount": risk_adjusted,
            "at_risk_amount": round(r.amount - risk_adjusted, 2),
        })

    breakdown.sort(key=lambda b: b["at_risk_amount"], reverse=True)

    total_face_value = sum(r.amount for r in receivables)
    total_risk_adjusted = round(sum(b["risk_adjusted_amount"] for b in breakdown), 2)

    return {
        "total_face_value": total_face_value,
        "total_risk_adjusted": total_risk_adjusted,
        "at_risk_amount": round(total_face_value - total_risk_adjusted, 2),
        "receivables": breakdown,
    }


def explain_receivables_risk(summary: Dict[str, Any]) -> List[str]:
    """
    Plain-English lines for the "why" panel, built the same way
    explanations.py builds everything else - directly from numbers
    already computed above, nothing invented.
    """
    if not summary["receivables"]:
        return []

    lines = []
    face = summary["total_face_value"]
    adjusted = summary["total_risk_adjusted"]
    at_risk = summary["at_risk_amount"]

    if at_risk <= 0:
        lines.append(
            f"₹{face:,.0f} in receivables is expected, and all of it is counted as "
            "reliably collectible based on customer payment history."
        )
    else:
        lines.append(
            f"₹{face:,.0f} in receivables is expected, but only ₹{adjusted:,.0f} is "
            f"counted as reliably collectible - ₹{at_risk:,.0f} is discounted based on "
            "customer payment history and isn't assumed to arrive on time."
        )

    unreliable = [b for b in summary["receivables"] if b["reliability_label"] == "UNRELIABLE"]
    for b in unreliable:
        lines.append(
            f"₹{b['amount']:,.0f} from '{b['description']}' is treated as high-risk udhaar "
            f"(reliability {b['reliability_score']*100:.0f}%) - only "
            f"₹{b['risk_adjusted_amount']:,.0f} of it is counted toward projected cash."
        )

    return lines
