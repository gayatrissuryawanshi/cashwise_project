"""
excel_loader.py
Turns the owner's uploaded Excel file into a BusinessState the rest of
the engine already understands (models.py / optimizer.py / etc).

This is the "person logs in -> uploads Excel -> dashboard appears" path.
Nothing about the core engine changes - this file just replaces "type
JSON by hand" with "read the same numbers off a spreadsheet".

Expected sheet layout (see BUSINESS_DATA_TEMPLATE.xlsx for a filled example)
------------------------------------------------------------------------
One sheet, three blocks, top to bottom:

BLOCK 1 - single business facts, two columns (label, value):
    Business_Name         <text>
    Business_Type          <text>
    Reporting_Date          <date>              (informational only)
    Location                <text>              (informational only)
    Monthly_Sales           <number>            (informational only)
    Monthly_Expenses        <number>            (informational only)
    Current_Cash            <number>            REQUIRED
    Minimum_Reserve         <number>            REQUIRED
    Risk_Buffer             <number>            optional, default 0

BLOCK 2 - obligations, three columns (label, amount, due date):
    Salary                  <number>    <date or blank>
    Rent                    <number>    <date or blank>
    Supplier Payment        <number>    <date or blank>
    ... any other row with a label + a number in this block becomes
    its own obligation. Blank due date -> treated as due in 30 days
    (a soft default, not urgent-today) so a missing date never
    silently disappears from safe-to-deploy.

A row that is just a section header (label with no number in the
amount column, e.g. "cash inflow and outflow") is skipped.

BLOCK 3 - receivables (udhaar) table, one header row then data rows:
    Customer_Name | Amount | Expected_Date | Payment_History
    Ramesh Kirana | 45000  | 2026-09-24    | on_time
    Suresh Traders| 25000  | 2026-09-24    | on_time,late,late

    Payment_History accepts either a single status (on_time / late /
    defaulted - this customer's most recent payment) or a comma
    separated list (their history, oldest first). Blank -> no history,
    which the engine treats as "benefit of the doubt" (counted in full)
    until this customer builds a track record.

BLOCK 4 - actions table, one header row then data rows:
    Action              | Maximum_Budget | Benefit_Score | Risk_Score | Min_Amount | Step
    Inventory Purchase  | 70000          | 85            | 30         |            |
    Marketing           | 30000          |               |            |            |

    Benefit_Score / Risk_Score / Min_Amount / Step are optional - if
    left blank, DEFAULT_ACTION_SCORES below is used (matched by the
    action's name, case-insensitively; falls back to a generic
    medium-benefit/medium-risk guess if the name isn't recognized).
    These are guesses, not learned - tune DEFAULT_ACTION_SCORES once
    you have a couple of real weeks of data on what actually pays off.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

import openpyxl

from .models import (
    Action,
    BusinessState,
    InvalidBusinessStateError,
    Obligation,
    Receivable,
    VALID_PAYMENT_STATUSES,
    days_until,
)

# Labels in Block 1 that are business facts, not obligations - anything
# in the "single value" block that ISN'T one of these becomes an
# obligation automatically (so a new row like "Insurance" just works
# without touching this file).
KNOWN_META_FIELDS = {
    "business_name", "business_type", "reporting_date", "location",
    "monthly_sales", "monthly_expenses",
}
KNOWN_CASH_FIELDS = {"current_cash", "minimum_reserve", "risk_buffer"}
SECTION_HEADER_HINTS = {"cash inflow and outflow", "for example:"}

# Default urgency for an obligation with no due date given - "soft
# reminder to fill it in" rather than either ignoring it (unsafe) or
# treating it as due today (overly conservative).
DEFAULT_OBLIGATION_DUE_DAYS = 30

# Fallback benefit/risk scores per action name, used only when the
# spreadsheet doesn't supply its own Benefit_Score / Risk_Score.
# Hand-picked, transparent, easy to override in the sheet directly.
DEFAULT_ACTION_SCORES = {
    "inventory purchase": (85, 30),
    "inventory": (85, 30),
    "supplier payment": (70, 20),
    "marketing": (60, 50),
    "equipment repair": (50, 40),
}
GENERIC_ACTION_SCORE = (60, 40)  # used when the action name isn't recognized above


class ExcelFormatError(ValueError):
    """Raised when the uploaded file doesn't match the expected layout,
    with a message specific enough for the frontend to show the owner
    exactly what to fix (e.g. 'Current_Cash is missing')."""
    pass


@dataclass
class BusinessMeta:
    """Informational fields for the top of the dashboard - not needed by
    the optimizer itself, just for display."""
    business_name: str = "Your Business"
    business_type: str = ""
    reporting_date: Optional[str] = None
    location: str = ""
    monthly_sales: Optional[float] = None
    monthly_expenses: Optional[float] = None


def _clean_label(value: Any) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip().lower()


def _to_number(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(",", "").strip())
    except ValueError:
        return None


def _to_date_or_days(value: Any, reference_date: Optional[date] = None) -> Optional[int]:
    """Accepts a datetime/date, an ISO string, or an already-numeric
    'days from now' and returns days_until_due/expected as an int."""
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return max(0, int(value))
    if isinstance(value, datetime):
        return days_until(value.date(), reference_date)
    if isinstance(value, date):
        return days_until(value, reference_date)
    text = str(value).strip()
    try:
        return days_until(datetime.fromisoformat(text).date(), reference_date)
    except ValueError:
        return None


def _parse_payment_history(value: Any) -> List[str]:
    if value is None or value == "":
        return []
    parts = [p.strip().lower() for p in str(value).split(",") if p.strip()]
    valid, invalid = [], []
    for p in parts:
        (valid if p in VALID_PAYMENT_STATUSES else invalid).append(p)
    if invalid:
        raise ExcelFormatError(
            f"Payment_History value(s) {invalid} not recognized - use one of "
            f"{sorted(VALID_PAYMENT_STATUSES)} (comma separated for multiple)."
        )
    return valid


def _find_action_scores(name: str) -> Tuple[float, float]:
    return DEFAULT_ACTION_SCORES.get(name.strip().lower(), GENERIC_ACTION_SCORE)


def _row_values(ws, row_idx: int, max_col: int = 6) -> List[Any]:
    return [ws.cell(row=row_idx, column=c).value for c in range(1, max_col + 1)]


def load_business_state_from_excel(
    path: str, reference_date: Optional[date] = None, sheet_name: Optional[str] = None
) -> Tuple[BusinessState, BusinessMeta]:
    """Main entry point. Reads a sheet of the workbook at `path` and
    returns (BusinessState, BusinessMeta) ready for optimizer.recommend().

    sheet_name: if given and present in the workbook, that sheet is read
    (used in the combined app, where the workbook also carries "Sales"
    and "Udhar" sheets for the ML models alongside the business-data
    sheet). Falls back to the first sheet otherwise, unchanged from the
    original single-purpose behavior.

    Raises ExcelFormatError (with a specific, owner-facing message) if a
    required field is missing, and InvalidBusinessStateError if the
    numbers themselves don't make sense (negative cash, etc - the same
    validation the JSON API already relies on)."""
    wb = openpyxl.load_workbook(path, data_only=True)
    if sheet_name and sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
    else:
        ws = wb[wb.sheetnames[0]]

    meta = BusinessMeta()
    cash_fields: Dict[str, float] = {}
    obligations: List[Obligation] = []
    receivables: List[Receivable] = []
    actions: List[Action] = []

    section = "kv"  # kv -> receivables -> actions, in the order they appear
    receivables_header_seen = False
    actions_header_seen = False

    row_idx = 1
    max_row = ws.max_row
    while row_idx <= max_row:
        row = _row_values(ws, row_idx)
        label_raw, col_b, col_c, col_d = row[0], row[1], row[2], row[3]
        label = _clean_label(label_raw)
        row_idx += 1

        if label == "" and all(v is None for v in row):
            continue  # blank spacer row

        # --- section transitions -------------------------------------------------
        if label == "column" and _clean_label(col_b) == "example":
            continue  # the "Column | Example" header of block 1
        if label in SECTION_HEADER_HINTS:
            continue
        if label == "action" and _clean_label(col_b) in ("maximum_budget", "max_amount"):
            section = "actions"
            actions_header_seen = True
            continue

        # --- Block 1: business facts + cash fields --------------------------------
        if section == "kv":
            if label in KNOWN_META_FIELDS:
                if label == "business_name":
                    meta.business_name = str(col_b) if col_b is not None else meta.business_name
                elif label == "business_type":
                    meta.business_type = str(col_b) if col_b is not None else ""
                elif label == "reporting_date":
                    meta.reporting_date = str(col_b) if col_b is not None else None
                elif label == "location":
                    meta.location = str(col_b) if col_b is not None else ""
                elif label == "monthly_sales":
                    meta.monthly_sales = _to_number(col_b)
                elif label == "monthly_expenses":
                    meta.monthly_expenses = _to_number(col_b)
                continue

            if label in KNOWN_CASH_FIELDS:
                num = _to_number(col_b)
                if num is not None:
                    cash_fields[label] = num
                continue

            # Anything else with a numeric value in this block is an
            # obligation (Salary, Rent, Supplier Payment, or a new one
            # the owner added).
            amount = _to_number(col_b)
            if amount is None:
                # Could be the start of the receivables table (a header
                # row like "Customer_Name | Amount | Expected_Date | ...")
                # or just a stray label - detect the receivables header
                # by its first cell and switch sections.
                if label and _clean_label(col_b) in ("amount",):
                    section = "receivables"
                    receivables_header_seen = True
                    continue
                # Not a recognized header and no number - skip quietly
                # (covers stray notes like "For example:" variants).
                continue
            days_until_due = _to_date_or_days(col_c, reference_date)
            if days_until_due is None:
                days_until_due = DEFAULT_OBLIGATION_DUE_DAYS
            obligations.append(
                Obligation(
                    name=str(label_raw).strip(),
                    amount=amount,
                    days_until_due=days_until_due,
                )
            )
            continue

        # --- Block 2: receivables --------------------------------------------------
        if section == "receivables":
            if label_raw is None:
                continue
            name = str(label_raw).strip()
            amount = _to_number(col_b)
            if amount is None:
                continue  # not a data row
            days = _to_date_or_days(col_c, reference_date)
            if days is None:
                raise ExcelFormatError(
                    f"Receivable '{name}' is missing a valid Expected_Date."
                )
            history = _parse_payment_history(col_d)
            receivables.append(
                Receivable(
                    amount=amount, days_until_expected=days,
                    description=name, payment_history=history,
                )
            )
            continue

        # --- Block 3: actions --------------------------------------------------
        if section == "actions":
            if label_raw is None:
                continue
            name = str(label_raw).strip()
            max_amount = _to_number(col_b)
            if max_amount is None:
                continue
            benefit_score = _to_number(row[2]) if len(row) > 2 else None
            risk_score = _to_number(row[3]) if len(row) > 3 else None
            min_amount = _to_number(row[4]) if len(row) > 4 else None
            step = _to_number(row[5]) if len(row) > 5 else None
            if benefit_score is None or risk_score is None:
                default_benefit, default_risk = _find_action_scores(name)
                benefit_score = default_benefit if benefit_score is None else benefit_score
                risk_score = default_risk if risk_score is None else risk_score
            actions.append(
                Action(
                    name=name, max_amount=max_amount,
                    benefit_score=benefit_score, risk_score=risk_score,
                    min_amount=min_amount or 0, step=step or 5000,
                )
            )
            continue

    if "current_cash" not in cash_fields:
        raise ExcelFormatError("Current_Cash is missing or blank - this is required.")
    if "minimum_reserve" not in cash_fields:
        raise ExcelFormatError("Minimum_Reserve is missing or blank - this is required.")
    if not actions:
        raise ExcelFormatError(
            "No actions found - add at least one row under the Action / "
            "Maximum_Budget table (e.g. Inventory Purchase, Marketing)."
        )

    state = BusinessState(
        cash=cash_fields["current_cash"],
        obligations=obligations,
        receivables=receivables,
        reserve=cash_fields["minimum_reserve"],
        risk_buffer=cash_fields.get("risk_buffer", 0.0),
        actions=actions,
    )
    return state, meta



