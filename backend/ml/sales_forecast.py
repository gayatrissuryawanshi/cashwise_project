import os
from pathlib import Path

import pandas as pd
import numpy as np
import joblib
from xgboost import XGBRegressor


# ==========================================
# VERCEL / LOCAL STORAGE
# ==========================================

# Vercel allows writing only inside /tmp.
# Locally, keep using the project's models/outputs folders.

if os.getenv("VERCEL"):
    MODELS_DIR = Path("/tmp/cashwise_models")
    OUTPUTS_DIR = Path("/tmp/cashwise_outputs")
else:
    BASE_DIR = Path(__file__).resolve().parent.parent
    MODELS_DIR = BASE_DIR / "models"
    OUTPUTS_DIR = BASE_DIR / "outputs"

MODELS_DIR.mkdir(parents=True, exist_ok=True)
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)


# ==========================================
# ML FEATURES
# ==========================================

FEATURES = [
    "day_of_week",
    "day_of_month",
    "month",
    "lag_1",
    "lag_7",
    "rolling_7",
    "rolling_14",
]


# ==========================================
# READ SALES SHEET FROM EXCEL
# ==========================================

def load_sales_data(file_path):

    df = pd.read_excel(
        file_path,
        sheet_name="Sales",
    )

    required_columns = [
        "Date",
        "Sales",
    ]

    for column in required_columns:
        if column not in df.columns:
            raise ValueError(
                f"Excel file must contain: {column}"
            )

    df["Date"] = pd.to_datetime(
        df["Date"],
        errors="coerce",
    )

    df["Sales"] = pd.to_numeric(
        df["Sales"],
        errors="coerce",
    )

    df = df.dropna(
        subset=[
            "Date",
            "Sales",
        ]
    )

    df = df[
        df["Sales"] >= 0
    ]

    df = df.sort_values(
        "Date"
    )

    df = (
        df.groupby(
            "Date",
            as_index=False,
        )["Sales"]
        .sum()
    )

    df = df.reset_index(
        drop=True
    )

    return df


# ==========================================
# CREATE ML FEATURES
# ==========================================

def create_features(df):

    data = df.copy()

    data["day_of_week"] = (
        data["Date"].dt.dayofweek
    )

    data["day_of_month"] = (
        data["Date"].dt.day
    )

    data["month"] = (
        data["Date"].dt.month
    )

    data["lag_1"] = (
        data["Sales"].shift(1)
    )

    data["lag_7"] = (
        data["Sales"].shift(7)
    )

    data["rolling_7"] = (
        data["Sales"]
        .shift(1)
        .rolling(7)
        .mean()
    )

    data["rolling_14"] = (
        data["Sales"]
        .shift(1)
        .rolling(14)
        .mean()
    )

    data = data.dropna()

    return data


# ==========================================
# TRAIN SALES MODEL
# ==========================================

def train_sales_model(file_path):

    print("\nLoading sales data...")

    df = load_sales_data(
        file_path
    )

    if len(df) < 60:
        raise ValueError(
            "At least 60 days of sales "
            "history is recommended."
        )

    data = create_features(
        df
    )

    X = data[
        FEATURES
    ]

    y = data[
        "Sales"
    ]

    print(
        f"Training using {len(data)} records..."
    )

    model = XGBRegressor(
        n_estimators=300,
        max_depth=4,
        learning_rate=0.05,
        objective="reg:squarederror",
        random_state=42,
    )

    model.fit(
        X,
        y
    )

    # Save trained model
    joblib.dump(
        model,
        MODELS_DIR / "sales_model.pkl"
    )

    print(
        "\nSALES MODEL TRAINED SUCCESSFULLY!"
    )

    print(
        f"Saved as: {MODELS_DIR / 'sales_model.pkl'}"
    )

    return model


# ==========================================
# CREATE FEATURES FOR FUTURE DATE
# ==========================================

def create_future_features(
    history,
    future_date,
):

    sales = history[
        "Sales"
    ].tolist()

    lag_1 = sales[-1]

    if len(sales) >= 7:
        lag_7 = sales[-7]
    else:
        lag_7 = np.mean(sales)

    rolling_7 = np.mean(
        sales[-7:]
    )

    rolling_14 = np.mean(
        sales[-14:]
    )

    features = {
        "day_of_week":
            future_date.dayofweek,

        "day_of_month":
            future_date.day,

        "month":
            future_date.month,

        "lag_1":
            lag_1,

        "lag_7":
            lag_7,

        "rolling_7":
            rolling_7,

        "rolling_14":
            rolling_14,
    }

    return pd.DataFrame(
        [features]
    )


# ==========================================
# FUTURE SALES FORECAST
# ==========================================

def forecast_sales(
    file_path,
    days=30,
):

    model_path = (
        MODELS_DIR
        / "sales_model.pkl"
    )

    # If model does not exist,
    # train it automatically.
    if not model_path.exists():

        print(
            "Sales model not found."
        )

        print(
            "Training sales model..."
        )

        train_sales_model(
            file_path
        )

    model = joblib.load(
        model_path
    )

    df = load_sales_data(
        file_path
    )

    history = df.copy()

    predictions = []

    last_date = (
        history["Date"].iloc[-1]
    )

    for i in range(
        1,
        days + 1,
    ):

        future_date = (
            last_date
            + pd.Timedelta(
                days=i
            )
        )

        features = (
            create_future_features(
                history,
                future_date,
            )
        )

        prediction = (
            model.predict(
                features
            )[0]
        )

        prediction = max(
            0,
            prediction
        )

        predictions.append(
            {
                "Date":
                    future_date,

                "Predicted_Sales":
                    round(
                        prediction,
                        2,
                    ),
            }
        )

        history.loc[
            len(history)
        ] = [
            future_date,
            prediction,
        ]

    result = pd.DataFrame(
        predictions
    )

    result.to_csv(
        OUTPUTS_DIR
        / "sales_forecast.csv",
        index=False,
    )

    return result


# ==========================================
# TEST THIS FILE DIRECTLY
# ==========================================

if __name__ == "__main__":

    print(
        "sales_forecast.py is working."
    )