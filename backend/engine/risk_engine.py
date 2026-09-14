"""
risk_engine.py
Turns raw numbers (safe cash, proposed spend, remaining buffer) into
a human-readable risk classification. Kept deliberately simple and
rule-based / transparent - this is what you EXPLAIN to the judges,
so it must never be a black box.
"""

from typing import Literal

RiskLevel = Literal["LOW", "MEDIUM", "HIGH"]


def classify_risk(remaining_after_action: float, reserve: float, obligations_total: float) -> RiskLevel:
    """
    remaining_after_action: cash left once proposed spend is deducted
    reserve: minimum reserve the business wants to always keep
    obligations_total: sum of known upcoming obligations
    """
    safety_floor = reserve + obligations_total

    if remaining_after_action < 0:
        return "HIGH"
    if remaining_after_action < safety_floor * 0.5:
        return "HIGH"
    if remaining_after_action < safety_floor:
        return "MEDIUM"
    return "LOW"


def safety_floor(reserve: float, obligations_total: float) -> float:
    return reserve + obligations_total
