"""
counterfactuals.py
"What if I skip this?" - Person 3's counterfactual explanations feature.

explanations.py already says *why* the recommended allocation looks the
way it does, built entirely from real numbers. This module answers the
natural follow-up an owner (or a judge) will ask: what would change if
one of the funded actions were skipped?

It reuses optimize_allocation() from optimizer.py with that action's
max_amount forced to 0 - the same optimizer just runs again on a
constrained action list. No new numbers are invented, nothing is
predicted - it's the identical brute-force logic, re-run once per
funded action.
"""

from typing import Dict, Any, List
from .models import BusinessState, Action, InvalidBusinessStateError
from .optimizer import optimize_allocation


def _fmt(amount: float) -> str:
    return f"₹{amount:,.0f}"


def _state_without_action(state: BusinessState, action_name: str) -> BusinessState:
    """Returns a NEW BusinessState where the named action's max_amount
    (and min_amount, so a min>max validation error can't happen) are
    forced to 0 - i.e. the optimizer is no longer allowed to fund it at
    all. Does not mutate the original state or its Actions, matching the
    same non-mutating pattern apply_predicted_demand_cap() uses in
    optimizer.py."""
    modified_actions = [
        Action(
            name=a.name,
            max_amount=0.0 if a.name == action_name else a.max_amount,
            benefit_score=a.benefit_score, risk_score=a.risk_score,
            min_amount=0.0 if a.name == action_name else a.min_amount,
            step=a.step,
        )
        for a in state.actions
    ]
    return BusinessState(
        cash=state.cash, obligations=state.obligations, reserve=state.reserve,
        actions=modified_actions, risk_buffer=state.risk_buffer, receivables=state.receivables,
    )


def build_counterfactual_for_action(state: BusinessState, action_name: str,
                                     original_allocation: Dict[str, float]) -> Dict[str, Any]:
    """
    Re-runs the optimizer with `action_name` forced to 0 and compares the
    result to the original recommendation.

    Raises InvalidBusinessStateError if action_name doesn't exist on this
    business - mirrors the guard apply_predicted_demand_cap() uses for
    the same situation.
    """
    if action_name not in {a.name for a in state.actions}:
        raise InvalidBusinessStateError(
            f"Cannot build a counterfactual for '{action_name}': no action with that name exists."
        )

    original_amount = original_allocation.get(action_name, 0.0)
    original_remaining_cash = state.cash - sum(original_allocation.values())

    without_state = _state_without_action(state, action_name)
    without_result = optimize_allocation(without_state)
    new_allocation = without_result["recommended_allocation"]

    reallocated_to = {
        name: amt for name, amt in new_allocation.items()
        if name != action_name and amt > original_allocation.get(name, 0.0)
    }
    change_in_remaining_cash = round(without_result["remaining_cash"] - original_remaining_cash, 2)

    readable_name = action_name.replace("_", " ")
    if reallocated_to:
        moved_to = ", ".join(
            f"{_fmt(amt)} to {name.replace('_', ' ')}" for name, amt in reallocated_to.items()
        )
        explanation = f"If you skip {readable_name} ({_fmt(original_amount)}), {moved_to} instead."
        if change_in_remaining_cash > 0:
            explanation += f" {_fmt(change_in_remaining_cash)} more stays in reserve."
    elif change_in_remaining_cash > 0:
        explanation = (
            f"If you skip {readable_name} ({_fmt(original_amount)}), no other action absorbs it - "
            f"{_fmt(change_in_remaining_cash)} more simply stays in reserve."
        )
    else:
        explanation = (
            f"If you skip {readable_name} ({_fmt(original_amount)}), the rest of the plan is unchanged."
        )

    return {
        "action_name": action_name,
        "original_amount": original_amount,
        "new_allocation": new_allocation,
        "new_total_allocated": without_result["total_allocated"],
        "new_remaining_cash": without_result["remaining_cash"],
        "change_in_remaining_cash": change_in_remaining_cash,
        "explanation": explanation,
    }


def build_counterfactuals(state: BusinessState, original_allocation: Dict[str, float]) -> List[Dict[str, Any]]:
    """
    Builds a "what if I skip X" counterfactual for every action that
    received a nonzero allocation in the original recommendation.
    Skipping an action that was already funded at ₹0 wouldn't change
    anything, so those aren't included.
    """
    funded_actions = [name for name, amt in original_allocation.items() if amt > 0]
    return [
        build_counterfactual_for_action(state, name, original_allocation)
        for name in funded_actions
    ]
