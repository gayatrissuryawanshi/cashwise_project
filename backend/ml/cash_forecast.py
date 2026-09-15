import os
from pathlib import Path

import pandas as pd

from .sales_forecast import forecast_sales
from .udhar_model import load_udhar_data


# ============================================================
# VERCEL-SAFE OUTPUT STORAGE
# ============================================================

if os.getenv("VERCEL"):
    OUTPUTS_DIR = Path("/tmp/cashwise_outputs")
else:
    BASE_DIR = Path(__file__).resolve().parent.parent
    OUTPUTS_DIR = BASE_DIR / "outputs"

OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)


def calculate_outstanding(file_path):
    df = load_udhar_data(file_path)

    unpaid = df[
        df["Payment_Date"].isna()
    ].copy()

    if unpaid.empty:
        return 0

    return unpaid["Amount"].sum()


def calculate_expected_collections(file_path):
    df = load_udhar_data(file_path)

    unpaid = df[
        df["Payment_Date"].isna()
    ].copy()

    if unpaid.empty:
        return 0

    paid = df.dropna(
        subset=["Payment_Date"]
    ).copy()

    if paid.empty:
        return 0

    paid["delay"] = (
        paid["Payment_Date"]
        - paid["Due_Date"]
    ).dt.days

    customer_delay = (
        paid.groupby("Customer_ID")["delay"]
        .mean()
    )

    expected = 0

    for _, row in unpaid.iterrows():
        customer = row["Customer_ID"]
        amount = row["Amount"]

        if customer in customer_delay.index:
            avg_delay = customer_delay[customer]

            if avg_delay <= 0:
                expected += amount
            elif avg_delay <= 15:
                expected += amount * 0.75
            else:
                expected += amount * 0.40
        else:
            expected += amount * 0.50

    return expected


def create_cash_forecast(file_path, days=30):
    print("\nCreating cash-flow forecast...")

    sales_forecast = forecast_sales(
        file_path,
        days=days,
    )

    outstanding = calculate_outstanding(
        file_path
    )

    expected_collections = (
        calculate_expected_collections(
            file_path
        )
    )

    daily_collection = (
        expected_collections / days
        if days > 0
        else 0
    )

    cash = sales_forecast.copy()

    cash["Expected_Collections"] = (
        daily_collection
    )

    cash["Expected_Cash_Inflow"] = (
        cash["Predicted_Sales"]
        + cash["Expected_Collections"]
    )

    cash.to_csv(
        OUTPUTS_DIR / "cash_forecast.csv",
        index=False,
    )

    print("\n")
    print("=" * 55)
    print("          CASH FLOW FORECAST")
    print("=" * 55)

    print(
        f"\nOutstanding Udhar : "
        f"₹{outstanding:,.2f}"
    )

    print(
        f"Expected Collections : "
        f"₹{expected_collections:,.2f}"
    )

    print(
        f"Expected Sales : "
        f"₹{cash['Predicted_Sales'].sum():,.2f}"
    )

    print(
        f"Expected Cash Inflow : "
        f"₹{cash['Expected_Cash_Inflow'].sum():,.2f}"
    )

    print("\nSaved to:")

    print(
        f"{OUTPUTS_DIR / 'cash_forecast.csv'}"
    )

    return cash


if __name__ == "__main__":
    print(
        "cash_forecast.py is working."
    )