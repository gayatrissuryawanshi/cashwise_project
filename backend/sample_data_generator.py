"""
sample_data_generator.py
Builds BUSINESS_DATA_TEMPLATE.xlsx - a single workbook with all three
sheets the combined app understands:

    BusinessData - cash, obligations, receivables, actions
                   (decision engine's format)
    Sales        - daily sales history (forecast_new's format)
    Udhar        - customer credit/payment history (forecast_new's format)

Run directly to (re)generate the template:
    python sample_data_generator.py
"""

import random
from datetime import date, timedelta

import openpyxl


def build_workbook(path: str, seed: int = 42):
    random.seed(seed)
    wb = openpyxl.Workbook()

    # ------------------------------------------------------------------
    # Sheet 1: BusinessData
    # ------------------------------------------------------------------
    ws = wb.active
    ws.title = "BusinessData"

    today = date.today()
    receivable_date = today + timedelta(days=20)

    rows = [
        ("Column", "Example"),
        ("Business_Name", "Shree Ganesh Grocery"),
        ("Business_Type", "Retail / Kirana Store"),
        ("Reporting_Date", today.isoformat()),
        ("Location", "Pune, Maharashtra"),
        ("Monthly_Sales", 180000),
        ("Monthly_Expenses", 95000),
        ("Current_Cash", 250000),
        ("Minimum_Reserve", 40000),
        ("Risk_Buffer", 10000),
        ("Salary", 45000, (today + timedelta(days=10)).isoformat()),
        ("Rent", 20000, (today + timedelta(days=15)).isoformat()),
        ("Supplier Payment", 55000, (today + timedelta(days=20)).isoformat()),
        (None, None, None, None),
        ("Customer_Name", "Amount", "Expected_Date", "Payment_History"),
        ("Ramesh Kirana", 45000, receivable_date.isoformat(), "on_time,on_time,on_time"),
        ("Suresh Traders", 25000, receivable_date.isoformat(), "on_time,late,late"),
        ("Priya Fashions", 30000, receivable_date.isoformat(), "on_time,late"),
        ("Vikram General Store", 15000, receivable_date.isoformat(), ""),
        (None, None, None, None),
        ("Action", "Maximum_Budget", "Benefit_Score", "Risk_Score", "Min_Amount", "Step"),
        ("Inventory Purchase", 70000, 85, 30, 0, 5000),
        ("Marketing", 30000, 60, 50, 0, 5000),
        ("Equipment Repair", 20000, 50, 40, 0, 5000),
    ]
    for row in rows:
        ws.append(row)

    # ------------------------------------------------------------------
    # Sheet 2: Sales (>= 60 days required to train the sales model)
    # ------------------------------------------------------------------
    ws_sales = wb.create_sheet("Sales")
    ws_sales.append(["Date", "Sales"])
    start = today - timedelta(days=120)
    base = 6000
    for i in range(120):
        d = start + timedelta(days=i)
        weekday_bump = 1.3 if d.weekday() in (5, 6) else 1.0
        noise = random.uniform(0.85, 1.15)
        sales = round(base * weekday_bump * noise, 2)
        ws_sales.append([d.isoformat(), sales])

    # ------------------------------------------------------------------
    # Sheet 3: Udhar (customer credit history - needs repeat customers
    # with several payments each, within the last ~90 days, for the
    # udhaar model to have enough training rows).
    # ------------------------------------------------------------------
    ws_udhar = wb.create_sheet("Udhar")
    ws_udhar.append(["Customer_ID", "Credit_Date", "Amount", "Due_Date", "Payment_Date"])

    customers = {
        # name -> (typical delay in days, +/- jitter) - lets the demo
        # show one reliable, one borderline and one consistently late
        # customer, so the ML predictions (and the resulting reliability
        # adjustments) are easy to sanity-check by eye.
        "Ramesh Kirana": (0, 1),          # pays on time
        "Suresh Traders": (6, 3),         # pays a bit late
        "Priya Fashions": (3, 2),         # mixed
        "Vikram General Store": (12, 4),  # consistently late
    }

    credit_start = today - timedelta(days=95)
    for customer, (typical_delay, jitter) in customers.items():
        for i in range(8):
            credit_date = credit_start + timedelta(days=i * 11 + random.randint(0, 2))
            due_date = credit_date + timedelta(days=14)
            amount = random.choice([8000, 12000, 15000, 20000])
            is_last_two = i >= 6  # leave the most recent 1-2 invoices unpaid
            if is_last_two and random.random() < 0.6:
                payment_date = ""  # still outstanding -> shows up as Outstanding
            else:
                delay = max(-2, round(random.gauss(typical_delay, jitter)))
                payment_date = (due_date + timedelta(days=delay)).isoformat()
            ws_udhar.append([customer, credit_date.isoformat(), amount, due_date.isoformat(), payment_date])

    wb.save(path)
    return path


if __name__ == "__main__":
    build_workbook("BUSINESS_DATA_TEMPLATE.xlsx")
    print("Wrote BUSINESS_DATA_TEMPLATE.xlsx")
