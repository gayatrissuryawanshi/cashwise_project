"""
fragility.py
Fragility / sensitivity check - Person 3's addition.

The what-if simulator (scenario.py) already answers "is this plan safe
today?" - a single point-in-time answer built on today's receivables
data, treating every receivable as arriving exactly when expected. This
module asks a different question: how fragile is that answer? If a
customer's udhaar arrives a bit later than expected, does the plan still
hold, or does it tip into risk?

Most cash-flow tools give a single point estimate with no robustness
signal at all. This re-runs the exact same what-if simulator
(scenario.simulate_decision) with every receivable pushed back by a
handful of test delays, and reports the first delay at which the
resulting risk_level gets worse than the baseline (no-delay) case.
Nothing new is predicted - the same transparent risk_engine.classify_risk
rules just get applied again, against a shifted timeline.
"""

from typing import Dict, Any, List, Optional
from .models import BusinessState, Receivable, InvalidBusinessStateError
from .scenario import simulate_decision

RISK_RANK = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}

DEFAULT_DELAY_SCENARIOS_DAYS = [5, 10, 15]


def _state_with_delayed_receivables(state: BusinessState, delay_days: int) -> BusinessState:
    """Returns a NEW BusinessState where every receivable's
    days_until_expected is pushed back by delay_days - simulating slower
    customer collections across the board. Obligations are untouched;
    this is specifically about receivable-side risk. Does not mutate the
    original state or its Receivables, matching the non-mutating pattern
    used elsewhere in the engine (apply_predicted_demand_cap,
    counterfactuals._state_without_action)."""
    delayed_receivables = [
        Receivable(
            amount=r.amount,
            days_until_expected=r.days_until_expected + delay_days,
            description=r.description,
            payment_history=r.payment_history,
            reliability_score=r.reliability_score,
        )
        for r in state.receivables
    ]
    return BusinessState(
        cash=state.cash, obligations=state.obligations, reserve=state.reserve,
        actions=state.actions, risk_buffer=state.risk_buffer, receivables=delayed_receivables,
    )


def build_fragility_report(state: BusinessState, spend_now: float, horizon_days: int = 30,
                            delay_scenarios_days: Optional[List[int]] = None) -> Dict[str, Any]:
    """
    Runs the what-if simulator at increasing receivable-delay lengths and
    reports where (if anywhere) the risk level gets worse than the
    baseline (no-delay) case.

    Returns:
        baseline              -> risk/minimum-cash at 0 delay
        scenarios             -> one entry per tested delay, same shape
        is_fragile             -> True if any tested delay makes risk worse
        fragility_point_days   -> the first delay (in days) where that
                                   happens, or None if the plan held at
                                   every tested delay
        explanation            -> plain-English summary, built only from
                                   the numbers above
    """
    if horizon_days <= 0:
        raise InvalidBusinessStateError(f"horizon_days must be positive (got {horizon_days}).")
    if spend_now < 0:
        raise InvalidBusinessStateError(f"spend_now cannot be negative (got ₹{spend_now:,.0f}).")

    delays = sorted(delay_scenarios_days) if delay_scenarios_days else DEFAULT_DELAY_SCENARIOS_DAYS

    baseline_result = simulate_decision(state, spend_now, horizon_days)
    baseline = {
        "delay_days": 0,
        "risk_level": baseline_result["risk_level"],
        "minimum_projected_cash": baseline_result["minimum_projected_cash"],
        "minimum_at_day": baseline_result["minimum_at_day"],
    }
    baseline_rank = RISK_RANK[baseline["risk_level"]]

    scenarios = []
    fragility_point_days = None
    for delay in delays:
        delayed_state = _state_with_delayed_receivables(state, delay)
        result = simulate_decision(delayed_state, spend_now, horizon_days)
        scenario_entry = {
            "delay_days": delay,
            "risk_level": result["risk_level"],
            "minimum_projected_cash": result["minimum_projected_cash"],
            "minimum_at_day": result["minimum_at_day"],
        }
        scenarios.append(scenario_entry)
        if fragility_point_days is None and RISK_RANK[result["risk_level"]] > baseline_rank:
            fragility_point_days = delay

    is_fragile = fragility_point_days is not None

    if not state.receivables:
        explanation = (
            "This business has no receivables on record, so delaying customer "
            "collections has no effect on the plan - risk stays the same regardless of delay."
        )
    elif is_fragile:
        flip_scenario = next(s for s in scenarios if s["delay_days"] == fragility_point_days)
        explanation = (
            f"This plan starts at {baseline['risk_level']} risk, but becomes "
            f"{flip_scenario['risk_level']} risk if receivables are delayed by just "
            f"{fragility_point_days} days - it depends on customers paying close to on time."
        )
    else:
        explanation = (
            f"This plan stays {baseline['risk_level']} risk even if receivables are delayed "
            f"by up to {max(delays)} days - it isn't sensitive to slower customer collections."
        )

    return {
        "baseline": baseline,
        "scenarios": scenarios,
        "is_fragile": is_fragile,
        "fragility_point_days": fragility_point_days,
        "explanation": explanation,
    }
