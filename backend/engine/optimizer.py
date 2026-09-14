"""
optimizer.py
The heart of the product.

    calculate_safe_to_deploy()  -> how much cash can we touch at all?
    generate_allocations()      -> brute-force valid combinations of actions
    score_allocation()          -> transparent scoring function
    optimize_allocation()       -> pick the best valid allocation
    recommend()                 -> full pipeline, ready for the API layer

Deliberately NOT using OR-Tools yet (per the plan: prove the logic with
brute force first, swap in a real solver only if you have time left).
"""

import itertools
from typing import List, Dict, Any, Optional

from .models import BusinessState, Action, InvalidBusinessStateError, InventoryItem, suggest_inventory_max_amount
from .risk_engine import classify_risk, safety_floor
from .explanations import build_why
from .udhaar_risk import summarize_receivables_risk


def calculate_safe_to_deploy(state: BusinessState) -> float:
    """
    Safe-to-deploy = cash - upcoming obligations - reserve - risk buffer
    This is the single most important number in the whole product.
    """
    safe = state.cash - state.total_obligations() - state.reserve - state.risk_buffer
    return max(0.0, safe)


def apply_predicted_demand_cap(state: BusinessState, inventory_items: List[InventoryItem],
                                 action_name: str = "inventory") -> "tuple[BusinessState, Dict[str, Any]]":
    """
    Uses real INVENTORY.predicted_demand data to cap how much the named
    action (normally "inventory") can be allocated - so the optimizer
    can't recommend buying more stock than the business can realistically
    sell.

    Returns a NEW BusinessState (does not mutate the one passed in - the
    original `state` and its Actions are left untouched, so callers can
    safely reuse a shared/sample BusinessState across multiple requests
    without one request's demand data leaking into another's).
    """
    if not inventory_items:
        return state, {"applied": False}

    suggested_max = suggest_inventory_max_amount(inventory_items)

    matching_action = next((a for a in state.actions if a.name == action_name), None)
    if matching_action is None:
        raise InvalidBusinessStateError(
            f"Cannot apply predicted demand cap: no action named '{action_name}' exists "
            f"in this business's action list."
        )
    if suggested_max < matching_action.min_amount:
        raise InvalidBusinessStateError(
            f"Predicted demand (₹{suggested_max:,.0f}) is below the minimum required "
            f"allocation (₹{matching_action.min_amount:,.0f}) for '{action_name}'."
        )

    previous_max = matching_action.max_amount
    new_actions = [
        Action(
            name=a.name,
            max_amount=suggested_max if a.name == action_name else a.max_amount,
            benefit_score=a.benefit_score, risk_score=a.risk_score,
            min_amount=a.min_amount, step=a.step,
        )
        for a in state.actions
    ]
    new_state = BusinessState(
        cash=state.cash, obligations=state.obligations, reserve=state.reserve,
        actions=new_actions, risk_buffer=state.risk_buffer, receivables=state.receivables,
    )

    info = {
        "applied": True,
        "action_name": action_name,
        "previous_max_amount": previous_max,
        "new_max_amount": suggested_max,
        "num_items": len(inventory_items),
        "total_predicted_demand": sum(i.predicted_demand for i in inventory_items),
    }
    return new_state, info


def generate_allocations(actions: List[Action], safe_cash: float) -> List[Dict[str, float]]:
    """
    Brute-force every combination of action amounts (stepped by each
    action's granularity), keep only combinations whose total spend
    is <= safe_cash. This is O(n^k) but for 3-4 actions and reasonable
    step sizes it's instant, and it's trivially easy to debug/explain.
    """
    ranges = []
    for a in actions:
        steps = int(a.max_amount // a.step) + 1
        values = [min(i * a.step, a.max_amount) for i in range(steps)]
        ranges.append(values)

    valid_allocations = []
    for combo in itertools.product(*ranges):
        total = sum(combo)
        if total <= safe_cash:
            allocation = {a.name: amt for a, amt in zip(actions, combo)}
            valid_allocations.append(allocation)

    return valid_allocations


def score_allocation(allocation: Dict[str, float], actions: List[Action]) -> float:
    """
    Sum of (per-action score * amount allocated), so larger allocations
    to high-scoring actions are rewarded, but only up to their max_amount
    (already enforced upstream). Unallocated safe cash is implicitly
    "reserve", which we give a small positive score so the optimizer
    doesn't feel forced to spend everything.
    """
    action_lookup = {a.name: a for a in actions}
    total_score = 0.0
    for name, amount in allocation.items():
        a = action_lookup[name]
        # normalize by 10000 so scores stay in a sane range
        total_score += (amount / 10000.0) * a.score()
    return total_score


def optimize_allocation(state: BusinessState) -> Dict[str, Any]:
    safe_cash = calculate_safe_to_deploy(state)
    candidates = generate_allocations(state.actions, safe_cash)

    if not candidates:
        best = {a.name: 0.0 for a in state.actions}
    else:
        best = max(candidates, key=lambda alloc: score_allocation(alloc, state.actions))

    total_allocated = sum(best.values())
    remaining_reserve = state.cash - total_allocated

    return {
        "safe_to_deploy": safe_cash,
        "recommended_allocation": best,
        "total_allocated": total_allocated,
        "remaining_cash": remaining_reserve,
    }


def evaluate_proposed_spend(state: BusinessState, proposed_amount: float) -> Dict[str, Any]:
    """
    The "Don't Spend Yet" check. Compares what the owner WANTS to spend
    against what's actually safe, and returns a clear verdict + reason.
    """
    if proposed_amount < 0:
        raise InvalidBusinessStateError(
            f"proposed_amount cannot be negative (got ₹{proposed_amount:,.0f})."
        )

    safe_cash = calculate_safe_to_deploy(state)
    remaining_after = state.cash - proposed_amount
    obligations_total = state.total_obligations()
    floor = safety_floor(state.reserve, obligations_total)

    risk = classify_risk(remaining_after, state.reserve, obligations_total)
    is_safe = proposed_amount <= safe_cash

    excess = max(0.0, proposed_amount - safe_cash)

    return {
        "requested_amount": proposed_amount,
        "safe_amount": safe_cash,
        "is_safe": is_safe,
        "excess_amount": excess,
        "remaining_cash_if_spent": remaining_after,
        "risk_level": risk,
        "safety_floor": floor,
        "verdict": "APPROVED" if is_safe else "NOT RECOMMENDED",
        "reason": (
            f"Requested amount is within the safe-to-deploy limit of ₹{safe_cash:,.0f}."
            if is_safe else
            f"Spending ₹{proposed_amount:,.0f} would leave only ₹{remaining_after:,.0f}, "
            f"below the required safety floor of ₹{floor:,.0f} "
            f"(₹{obligations_total:,.0f} obligations + ₹{state.reserve:,.0f} reserve). "
            f"Reduce by at least ₹{excess:,.0f}."
        ),
    }


def build_reason_codes(state: BusinessState, allocation: Dict[str, float]) -> List[str]:
    """
    Cheap, transparent explanation generator. Not an LLM - these are
    derived directly from the same numbers the optimizer used, which
    is exactly what the "Why?" feature in the plan calls for.
    """
    codes = []
    for o in sorted(state.obligations, key=lambda x: x.days_until_due):
        codes.append(f"{o.name.lower().replace(' ', '_')}_due_in_{o.days_until_due}_days")
    for name, amt in allocation.items():
        if amt > 0:
            codes.append(f"allocated_{name}_{int(amt)}")
    return codes


def recommend(state: BusinessState, demand_cap_info: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Full pipeline entry point - this is what Person 1 calls from the API.
    demand_cap_info, if provided (from apply_predicted_demand_cap), gets
    surfaced as an extra line in the 'why' explanation."""
    # imported here, not at module level, to avoid a circular import:
    # counterfactuals.py itself calls optimize_allocation() from this file.
    from .counterfactuals import build_counterfactuals
    from .fragility import build_fragility_report

    result = optimize_allocation(state)
    obligations_total = state.total_obligations()
    risk = classify_risk(result["remaining_cash"], state.reserve, obligations_total)
    result["risk_level"] = risk
    result["reason_codes"] = build_reason_codes(state, result["recommended_allocation"])
    result["why"] = build_why(
        state=state,
        safe_cash=result["safe_to_deploy"],
        allocation=result["recommended_allocation"],
        remaining_cash=result["remaining_cash"],
        risk_level=risk,
    )
    result["receivables_risk"] = summarize_receivables_risk(state.receivables)
    counterfactuals = build_counterfactuals(state, result["recommended_allocation"])
    result["counterfactuals"] = counterfactuals
    result["why"]["counterfactual_reasons"] = [c["explanation"] for c in counterfactuals]
    fragility = build_fragility_report(state, spend_now=result["total_allocated"])
    result["fragility"] = fragility
    result["why"]["fragility_note"] = fragility["explanation"]
    if demand_cap_info and demand_cap_info.get("applied"):
        result["why"]["allocation_reasons"].append(
            f"The maximum inventory allocation was capped at "
            f"₹{demand_cap_info['new_max_amount']:,.0f}, based on predicted demand "
            f"across {demand_cap_info['num_items']} inventory item(s) - "
            f"buying beyond what's likely to sell isn't recommended."
        )
        result["demand_cap_applied"] = demand_cap_info
    return result
