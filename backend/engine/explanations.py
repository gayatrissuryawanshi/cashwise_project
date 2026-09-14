"""
explanations.py
Turns the engine's raw numbers into the plain-English "Why?" section
the plan calls for. IMPORTANT: every sentence here is built directly
from numbers the optimizer already calculated - nothing is invented.
If you later add an LLM to make this sound more natural, feed it
these strings/facts and have it rephrase them; never let it generate
new facts on its own.
"""

from typing import List, Dict, Any
from .models import BusinessState
from .udhaar_risk import summarize_receivables_risk, explain_receivables_risk


def _fmt(amount: float) -> str:
    return f"₹{amount:,.0f}"


def explain_safe_to_deploy(state: BusinessState, safe_cash: float) -> List[str]:
    """Plain-English breakdown of why the safe-to-deploy number is what it is."""
    lines = []
    lines.append(f"You currently have {_fmt(state.cash)} in cash.")

    if state.obligations:
        sorted_obligations = sorted(state.obligations, key=lambda o: o.days_until_due)
        for o in sorted_obligations:
            lines.append(f"₹{o.amount:,.0f} for {o.name} is due in {o.days_until_due} days.")
    else:
        lines.append("There are no upcoming obligations on record.")

    if state.reserve > 0:
        lines.append(f"You want to keep a minimum reserve of {_fmt(state.reserve)} at all times.")
    if state.risk_buffer > 0:
        lines.append(f"An extra risk buffer of {_fmt(state.risk_buffer)} is held back for uncertainty.")

    lines.append(f"After accounting for all of this, {_fmt(safe_cash)} is safe to deploy right now.")

    if state.receivables:
        risk_summary = summarize_receivables_risk(state.receivables)
        lines.append(
            "Note: this is separate from receivables, which aren't counted as "
            "safe-to-deploy yet since they haven't arrived."
        )
        lines.extend(explain_receivables_risk(risk_summary))
    return lines


def explain_allocation(state: BusinessState, allocation: Dict[str, float]) -> List[str]:
    """Plain-English reasons behind the recommended split."""
    action_lookup = {a.name: a for a in state.actions}
    lines = []

    funded = {name: amt for name, amt in allocation.items() if amt > 0}
    if not funded:
        lines.append("No allocation is recommended right now - it's safer to hold everything in reserve.")
        return lines

    # rank by amount, largest first, so the biggest decision is explained first
    for name, amount in sorted(funded.items(), key=lambda kv: kv[1], reverse=True):
        a = action_lookup.get(name)
        if a is None:
            continue
        readable_name = name.replace("_", " ")
        reason_bits = []
        if a.benefit_score >= 70:
            reason_bits.append(f"a high expected benefit ({a.benefit_score:.0f}/100)")
        elif a.benefit_score >= 40:
            reason_bits.append(f"a moderate expected benefit ({a.benefit_score:.0f}/100)")
        else:
            reason_bits.append(f"a modest expected benefit ({a.benefit_score:.0f}/100)")

        if a.risk_score <= 20:
            reason_bits.append(f"low risk ({a.risk_score:.0f}/100)")
        elif a.risk_score <= 50:
            reason_bits.append(f"moderate risk ({a.risk_score:.0f}/100)")
        else:
            reason_bits.append(f"higher risk ({a.risk_score:.0f}/100)")

        lines.append(
            f"{_fmt(amount)} is allocated to {readable_name}, which has {' and '.join(reason_bits)}."
        )

    unfunded = [name for name, amt in allocation.items() if amt == 0]
    if unfunded:
        readable = ", ".join(n.replace("_", " ") for n in unfunded)
        lines.append(f"No cash is allocated to {readable} in this recommendation.")

    return lines


def build_why(state: BusinessState, safe_cash: float, allocation: Dict[str, float],
              remaining_cash: float, risk_level: str) -> Dict[str, Any]:
    """
    Full explanation payload for the API/frontend. Structure:
        headline    -> one-line summary
        safe_cash_reasons  -> why this much is safe to deploy
        allocation_reasons -> why the money is split this way
        risk_note   -> one line about the resulting risk level
    """
    headline = (
        f"Of your {_fmt(state.cash)} in cash, {_fmt(safe_cash)} is safe to deploy. "
        f"{_fmt(remaining_cash)} stays as liquidity."
    )
    risk_note = {
        "LOW": "This plan keeps the business at LOW risk - upcoming obligations and the reserve are well covered.",
        "MEDIUM": "This plan carries MEDIUM risk - liquidity will be tighter than usual over the coming weeks.",
        "HIGH": "This plan carries HIGH risk - cash could fall short of upcoming obligations. Reconsider before proceeding.",
    }.get(risk_level, f"Risk level: {risk_level}.")

    return {
        "headline": headline,
        "safe_cash_reasons": explain_safe_to_deploy(state, safe_cash),
        "allocation_reasons": explain_allocation(state, allocation),
        "risk_note": risk_note,
    }
