"""
models.py
Simple dataclasses describing the business state that flows into
the decision engine. Kept intentionally plain (no ORM, no pydantic)
so Person 3 can iterate fast on Day 1. Person 1 can map these to/from
JSON for the FastAPI layer later.
"""

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import List, Dict, Optional, Union


class InvalidBusinessStateError(ValueError):
    """Raised when the numbers coming into the engine don't make sense.
    Kept as its own type so the API layer can catch it specifically and
    return a clean 400 instead of a raw 500 stack trace."""
    pass


def days_until(target_date: Union[str, date], reference_date: Optional[date] = None) -> int:
    """
    Converts an absolute date (e.g. Person 1's DB `due_date` / `expected_date`
    columns) into the relative "days from now" number this engine uses
    internally. Accepts a date object or an ISO string ("2026-09-25").
    Negative results (a date already in the past) are clamped to 0 -
    treat anything overdue as due today, i.e. maximum urgency.
    """
    if isinstance(target_date, str):
        target_date = datetime.fromisoformat(target_date).date()
    ref = reference_date or date.today()
    delta = (target_date - ref).days
    return max(0, delta)


# Allowed values for Receivable.payment_history - kept as a plain set (not
# an enum) so the API layer can validate raw strings coming from JSON
# without an extra conversion step.
VALID_PAYMENT_STATUSES = {"on_time", "late", "defaulted"}

# Transparent, hand-picked weights - not a learned model. Every score this
# produces can be explained in one sentence, which matters more than
# accuracy for a first version: an owner needs to trust *why* a customer's
# udhaar was discounted, not just the number.
_PAYMENT_STATUS_WEIGHTS = {"on_time": 1.0, "late": 0.5, "defaulted": 0.0}


@dataclass
class Receivable:
    """Mirrors the RECEIVABLES table: money expected to come IN.

    payment_history / reliability_score power the "Udhaar Risk Score":
    most cash-flow tools count every receivable at full face value, as if
    it were guaranteed to arrive on the expected date. In reality, Indian
    small businesses extend informal customer credit (udhaar) constantly,
    and some customers reliably pay late or don't pay at all. Treating a
    ₹50,000 receivable from a serial defaulter the same as ₹50,000 from a
    reliable customer overstates how much cash is really coming in.
    """
    amount: float
    days_until_expected: int
    description: str = "Receivable"
    # Chronological list of past payment outcomes for this customer, e.g.
    # ["on_time", "on_time", "late", "defaulted"]. Optional - an unknown
    # customer with no history yet is treated as reliable (benefit of the
    # doubt) until proven otherwise.
    payment_history: List[str] = field(default_factory=list)
    # 0-1 override. If a smarter model (or Person 2's forecast) already
    # produces a reliability score, pass it here directly and the
    # history-based calculation is skipped in favor of it.
    reliability_score: Optional[float] = None

    def __post_init__(self):
        if self.amount < 0:
            raise InvalidBusinessStateError(
                f"Receivable '{self.description}' has a negative amount (₹{self.amount:,.0f})."
            )
        if self.days_until_expected < 0:
            raise InvalidBusinessStateError(
                f"Receivable '{self.description}' has a negative days_until_expected "
                f"({self.days_until_expected})."
            )
        for status in self.payment_history:
            if status not in VALID_PAYMENT_STATUSES:
                raise InvalidBusinessStateError(
                    f"Receivable '{self.description}' has an invalid payment_history entry "
                    f"'{status}'. Must be one of {sorted(VALID_PAYMENT_STATUSES)}."
                )
        if self.reliability_score is not None and not (0 <= self.reliability_score <= 1):
            raise InvalidBusinessStateError(
                f"Receivable '{self.description}' has reliability_score={self.reliability_score}, "
                "expected 0-1."
            )

    def compute_reliability_score(self) -> float:
        """
        Returns a 0-1 score for how much of this receivable's face value
        should be counted as safely collectible cash.

        - An explicit reliability_score always wins, if provided.
        - Otherwise it's the average of transparent per-status weights
          across payment_history (on_time=1.0, late=0.5, defaulted=0.0).
        - With no history and no explicit score, defaults to 1.0 - a new
          customer isn't assumed risky just for being new.
        """
        if self.reliability_score is not None:
            return self.reliability_score
        if not self.payment_history:
            return 1.0
        scores = [_PAYMENT_STATUS_WEIGHTS[status] for status in self.payment_history]
        return sum(scores) / len(scores)

    def risk_adjusted_amount(self) -> float:
        """The portion of this receivable's face value that's realistic
        to count as incoming cash, given the customer's reliability."""
        return round(self.amount * self.compute_reliability_score(), 2)

    def reliability_label(self) -> str:
        """Human-readable bucket for the frontend - RELIABLE / MODERATE /
        UNRELIABLE, or UNKNOWN when there's no history or score to go on."""
        if self.reliability_score is None and not self.payment_history:
            return "UNKNOWN"
        score = self.compute_reliability_score()
        if score >= 0.8:
            return "RELIABLE"
        elif score >= 0.4:
            return "MODERATE"
        else:
            return "UNRELIABLE"


@dataclass
class InventoryItem:
    """Mirrors the INVENTORY table. Not required by the optimizer directly -
    used to derive a sensible max_amount for an 'inventory' Action via
    suggest_inventory_max_amount() below."""
    item_name: str
    quantity: float
    value: float
    predicted_demand: float = 0.0

    def __post_init__(self):
        if self.quantity < 0:
            raise InvalidBusinessStateError(
                f"Inventory item '{self.item_name}' has negative quantity ({self.quantity})."
            )
        if self.value < 0:
            raise InvalidBusinessStateError(
                f"Inventory item '{self.item_name}' has negative value (₹{self.value:,.0f})."
            )
        if self.predicted_demand < 0:
            raise InvalidBusinessStateError(
                f"Inventory item '{self.item_name}' has negative predicted_demand ({self.predicted_demand})."
            )


def suggest_inventory_max_amount(items: List["InventoryItem"], markup_buffer: float = 1.15) -> float:
    """
    Turns predicted_demand across inventory items into a suggested
    max_amount for the 'inventory' Action - i.e. don't let the optimizer
    recommend buying more stock than the business can realistically sell.
    markup_buffer gives a bit of headroom above raw predicted demand
    (default +15%) to account for restocking/lead-time slack.
    Falls back to 0 if there's no inventory data yet.
    """
    if not items:
        return 0.0
    total_demand_value = sum(item.predicted_demand for item in items)
    return round(total_demand_value * markup_buffer, 2)


@dataclass
class Obligation:
    name: str
    amount: float
    days_until_due: int

    def __post_init__(self):
        if not self.name or not str(self.name).strip():
            raise InvalidBusinessStateError("Obligation name cannot be empty.")
        if self.amount < 0:
            raise InvalidBusinessStateError(
                f"Obligation '{self.name}' has a negative amount (₹{self.amount:,.0f}). "
                "Amounts must be zero or positive."
            )
        if self.days_until_due < 0:
            raise InvalidBusinessStateError(
                f"Obligation '{self.name}' has a negative days_until_due ({self.days_until_due}). "
                "Use 0 for something due today."
            )

    @classmethod
    def from_due_date(cls, name: str, amount: float, due_date: Union[str, date],
                       reference_date: Optional[date] = None) -> "Obligation":
        """Convenience constructor matching the DB shape directly:
        OBLIGATIONS.description -> name, OBLIGATIONS.due_date -> days_until_due."""
        return cls(name=name, amount=amount, days_until_due=days_until(due_date, reference_date))

    def urgency(self) -> float:
        """
        Returns a multiplier 0-1+ representing how urgent this obligation is.
        Closer due date -> higher urgency -> weighs more heavily against
        safe-to-deploy cash.
        """
        if self.days_until_due <= 7:
            return 1.0
        elif self.days_until_due <= 14:
            return 0.75
        elif self.days_until_due <= 30:
            return 0.5
        else:
            return 0.25

    def weighted_amount(self) -> float:
        """Amount adjusted by urgency - used for prioritization, NOT for
        the raw safe-to-deploy subtraction (that uses full amount)."""
        return self.amount * self.urgency()


@dataclass
class Action:
    name: str
    max_amount: float
    benefit_score: float   # 0-100, how good this is for the business
    risk_score: float      # 0-100, how risky/uncertain this is
    min_amount: float = 0
    step: float = 5000     # granularity used when brute-forcing allocations

    def __post_init__(self):
        if not self.name or not str(self.name).strip():
            raise InvalidBusinessStateError("Action name cannot be empty.")
        if self.max_amount < 0:
            raise InvalidBusinessStateError(
                f"Action '{self.name}' has a negative max_amount (₹{self.max_amount:,.0f})."
            )
        if self.min_amount < 0:
            raise InvalidBusinessStateError(
                f"Action '{self.name}' has a negative min_amount (₹{self.min_amount:,.0f})."
            )
        if self.min_amount > self.max_amount:
            raise InvalidBusinessStateError(
                f"Action '{self.name}' has min_amount (₹{self.min_amount:,.0f}) greater than "
                f"max_amount (₹{self.max_amount:,.0f})."
            )
        if self.step <= 0:
            raise InvalidBusinessStateError(
                f"Action '{self.name}' has an invalid step ({self.step}). Step must be > 0, "
                "or the allocator will divide by zero."
            )
        # scores aren't fatal if slightly out of range, but wildly wrong
        # values (e.g. someone passing a rupee amount as a "score") should
        # fail loudly rather than silently produce a nonsense ranking.
        if not (0 <= self.benefit_score <= 100):
            raise InvalidBusinessStateError(
                f"Action '{self.name}' has benefit_score={self.benefit_score}, expected 0-100."
            )
        if not (0 <= self.risk_score <= 100):
            raise InvalidBusinessStateError(
                f"Action '{self.name}' has risk_score={self.risk_score}, expected 0-100."
            )

    def score(self) -> float:
        """Per-rupee desirability score, before allocation-size effects."""
        return self.benefit_score - (self.risk_score * 0.5)


@dataclass
class BusinessState:
    cash: float
    obligations: List[Obligation]
    reserve: float
    actions: List[Action]
    risk_buffer: float = 0.0  # extra cushion beyond obligations+reserve
    receivables: List[Receivable] = field(default_factory=list)

    def __post_init__(self):
        if self.cash < 0:
            raise InvalidBusinessStateError(
                f"Cash cannot be negative (got ₹{self.cash:,.0f})."
            )
        if self.reserve < 0:
            raise InvalidBusinessStateError(
                f"Reserve cannot be negative (got ₹{self.reserve:,.0f})."
            )
        if self.risk_buffer < 0:
            raise InvalidBusinessStateError(
                f"risk_buffer cannot be negative (got ₹{self.risk_buffer:,.0f})."
            )
        if not self.actions:
            raise InvalidBusinessStateError(
                "At least one action must be provided - the optimizer has "
                "nothing to allocate to otherwise."
            )
        names = [a.name for a in self.actions]
        if len(names) != len(set(names)):
            raise InvalidBusinessStateError(
                f"Action names must be unique, got duplicates in: {names}"
            )

    def total_obligations(self) -> float:
        return sum(o.amount for o in self.obligations)

    def total_receivables(self) -> float:
        return sum(r.amount for r in self.receivables)

    def weighted_obligations(self) -> float:
        return sum(o.weighted_amount() for o in self.obligations)
