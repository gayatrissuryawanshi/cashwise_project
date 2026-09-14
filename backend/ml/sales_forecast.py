import pandas as pd
import numpy as np
import joblib
from xgboost import XGBRegressor

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)
OUTPUTS_DIR = BASE_DIR / "outputs"
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
    "rolling_14"
]


# ==========================================
# READ SALES SHEET FROM EXCEL
# ==========================================

def load_sales_data(file_path):

    df = pd.read_excel(
        file_path,
        sheet_name="Sales"
    )

    required_columns = [
        "Date",
        "Sales"
    ]

    for column in required_columns:

        if column not in df.columns:

            raise ValueError(
                f"Excel file must contain: {column}"
            )

    # Convert date
    df["Date"] = pd.to_datetime(
        df["Date"],
        errors="coerce"
    )

    # Convert sales to numbers
    df["Sales"] = pd.to_numeric(
        df["Sales"],
        errors="coerce"
    )

    # Remove invalid rows
    df = df.dropna(
        subset=[
            "Date",
            "Sales"
        ]
    )

    # Sales cannot be negative
    df = df[
        df["Sales"] >= 0
    ]

    # Sort by date
    df = df.sort_values(
        "Date"
    )

    # If there are multiple sales
    # entries on the same date,
    # combine them
    df = (
        df.groupby(
            "Date",
            as_index=False
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

    # Calendar features
    data["day_of_week"] = (
        data["Date"].dt.dayofweek
    )

    data["day_of_month"] = (
        data["Date"].dt.day
    )

    data["month"] = (
        data["Date"].dt.month
    )

    # Previous sales
    data["lag_1"] = (
        data["Sales"].shift(1)
    )

    data["lag_7"] = (
        data["Sales"].shift(7)
    )

    # Rolling averages
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

    # Remove rows where
    # features aren't available
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

        random_state=42

    )

    model.fit(
        X,
        y
    )

    # Save model
    joblib.dump(
    model,
    MODELS_DIR / "sales_model.pkl"
)

    print(
        "\nSALES MODEL TRAINED SUCCESSFULLY!"
    )

    print(
        "Saved as: models/sales_model.pkl"
    )

    return model


# ==========================================
# CREATE FEATURES FOR FUTURE DATE
# ==========================================

def create_future_features(
    history,
    future_date
):

    sales = history[
        "Sales"
    ].tolist()

    # Previous day
    lag_1 = sales[-1]

    # Sales 7 days ago
    if len(sales) >= 7:

        lag_7 = sales[-7]

    else:

        lag_7 = np.mean(sales)

    # 7-day average
    rolling_7 = np.mean(
        sales[-7:]
    )

    # 14-day average
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
            rolling_14

    }

    return pd.DataFrame(
        [features]
    )


# ==========================================
# FUTURE SALES FORECAST
# ==========================================

def forecast_sales(
    file_path,
    days=30
):

    # Load trained model
    model = joblib.load(
    MODELS_DIR / "sales_model.pkl"
)

    # Load historical data
    df = load_sales_data(
        file_path
    )

    history = df.copy()

    predictions = []

    last_date = (
        history["Date"].iloc[-1]
    )

    # Predict one day at a time
    for i in range(
        1,
        days + 1
    ):

        future_date = (
            last_date
            + pd.Timedelta(days=i)
        )

        features = create_future_features(
            history,
            future_date
        )

        prediction = model.predict(
            features
        )[0]

        # Prevent negative prediction
        prediction = max(
            0,
            prediction
        )

        predictions.append({

            "Date":
                future_date,

            "Predicted_Sales":
                round(
                    prediction,
                    2
                )

        })

        # Add prediction to history
        # so next day's prediction
        # can use it
        history.loc[
            len(history)
        ] = [

            future_date,

            prediction

        ]

    result = pd.DataFrame(
        predictions
    )

    # Save forecast
    result.to_csv(
    OUTPUTS_DIR / "sales_forecast.csv",
    index=False
)

    return result


# ==========================================
# TEST THIS FILE DIRECTLY
# ==========================================

if __name__ == "__main__":

    print(
        "sales_forecast.py is working."
    )