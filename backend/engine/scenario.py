"""
scenario.py
The "what if I spend ₹X" simulator that powers the demo's killer moment.
Projects cash forward across upcoming obligations to see if a shortfall
appears. This is a simplified stand-in for Person 2's real forecast -
swap `project_cash_timeline` for their output once it's ready.
"""

from typing import Dict, Any, List
from .models import BusinessState, InvalidBusinessStateError
from .risk_engine import classify_risk


def project_cash_timeline(state: BusinessState, spend_now: float, horizon_days: int = 30) -> List[Dict[str, Any]]:
    """
    Day-by-day projection: start with cash - spend_now, then apply each
    obligation (cash out) on its due day and each receivable (cash in)
    on its expected day. This now uses real receivables data from the
    RECEIVABLES table - once Person 2's forecast model exists, expected
    sales can be added the same way (as additional Receivable-shaped
    inflow events).

    Each receivable's inflow is its Udhaar Risk Score-adjusted amount
    (risk_adjusted_amount()), not the raw face value - a customer with a
    history of late payment or default shouldn't bump the projected cash
    timeline by their full amount on the expected day. A receivable with
    no payment history yet still counts at full value (benefit of the
    doubt), so this is backward compatible with existing data.
    """
    timeline = []
    cash = state.cash - spend_now
    timeline.append({"day": 0, "cash": cash})

    outflow_events = [(o.days_until_due, -o.amount) for o in state.obligations]
    inflow_events = [(r.days_until_expected, r.risk_adjusted_amount()) for r in state.receivables]
    all_events = outflow_events + inflow_events

    checkpoints = sorted(set([7, 14, 21, 30, horizon_days] + [day for day, _ in all_events]))
    running_cash = cash
    for day in checkpoints:
        if day > horizon_days:
            continue
        net_change_today = sum(amount for event_day, amount in all_events if event_day == day)
        running_cash += net_change_today
        timeline.append({"day": day, "cash": running_cash})

    return timeline


def simulate_decision(state: BusinessState, proposed_amount: float, horizon_days: int = 30) -> Dict[str, Any]:
    if proposed_amount < 0:
        raise InvalidBusinessStateError(
            f"proposed_amount cannot be negative (got ₹{proposed_amount:,.0f})."
        )
    if horizon_days <= 0:
        raise InvalidBusinessStateError(
            f"horizon_days must be positive (got {horizon_days})."
        )
    timeline = project_cash_timeline(state, proposed_amount, horizon_days)
    min_point = min(timeline, key=lambda p: p["cash"])

    # Obligations are already subtracted day-by-day in the timeline, so here
    # we only compare the projected minimum against the reserve requirement
    # (passing 0 obligations avoids double-counting them in the risk floor).
    risk = classify_risk(min_point["cash"], state.reserve, obligations_total=0)
    shortfall = max(0.0, -min_point["cash"])

    return {
        "proposed_spend": proposed_amount,
        "timeline": timeline,
        "minimum_projected_cash": min_point["cash"],
        "minimum_at_day": min_point["day"],
        "shortfall": shortfall,
        "risk_level": risk,
    }
