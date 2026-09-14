import pandas as pd
import joblib

from sklearn.ensemble import RandomForestClassifier
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)
OUTPUTS_DIR = BASE_DIR / "outputs"
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)


FEATURES = [
    "avg_delay",
    "last_delay",
    "max_delay",
    "min_delay",
    "payment_count",
    "on_time_rate",
    "early_rate",
    "late_rate",
    "avg_amount"
]


def load_udhar_data(file_path):

    df = pd.read_excel(
        file_path,
        sheet_name="Udhar"
    )

    required_columns = [
        "Customer_ID",
        "Credit_Date",
        "Amount",
        "Due_Date",
        "Payment_Date"
    ]

    for column in required_columns:

        if column not in df.columns:
            raise ValueError(
                f"Udhar sheet must contain: {column}"
            )

    df["Credit_Date"] = pd.to_datetime(
        df["Credit_Date"],
        errors="coerce"
    )

    df["Due_Date"] = pd.to_datetime(
        df["Due_Date"],
        errors="coerce"
    )

    df["Payment_Date"] = pd.to_datetime(
        df["Payment_Date"],
        errors="coerce"
    )

    df["Amount"] = pd.to_numeric(
        df["Amount"],
        errors="coerce"
    )

    df = df.dropna(
        subset=[
            "Customer_ID",
            "Credit_Date",
            "Amount",
            "Due_Date"
        ]
    )

    df = df[df["Amount"] >= 0]

    df = df.sort_values(
        ["Customer_ID", "Credit_Date"]
    )

    return df.reset_index(drop=True)


def calculate_delay(df):

    data = df.copy()

    data["delay"] = (
        data["Payment_Date"]
        - data["Due_Date"]
    ).dt.days

    return data


def classify_delay(delay):

    if delay < 0:
        return "EARLY"

    elif delay == 0:
        return "ON TIME"

    else:
        return "LATE"


def get_last_three_months(group):

    group = group.sort_values(
        "Credit_Date"
    )

    if group.empty:
        return group

    latest_date = group["Credit_Date"].max()

    start_date = (
        latest_date
        - pd.Timedelta(days=90)
    )

    recent = group[
        group["Credit_Date"] >= start_date
    ].copy()

    return recent


def create_training_data(df):

    paid = df.dropna(
        subset=["Payment_Date"]
    ).copy()

    paid = calculate_delay(
        paid
    )

    paid["label"] = (
        paid["delay"]
        .apply(classify_delay)
    )

    rows = []

    for customer_id, group in paid.groupby(
        "Customer_ID"
    ):

        group = group.sort_values(
            "Credit_Date"
        )

        if len(group) < 2:
            continue

        for i in range(
            1,
            len(group)
        ):

            history = group.iloc[:i]

            current = group.iloc[i]

            # Use only the previous
            # 3 months of history
            recent_history = (
                get_last_three_months(
                    history
                )
            )

            if recent_history.empty:
                continue

            delays = recent_history[
                "delay"
            ]

            rows.append({

                "Customer_ID":
                    customer_id,

                "avg_delay":
                    delays.mean(),

                "last_delay":
                    delays.iloc[-1],

                "max_delay":
                    delays.max(),

                "min_delay":
                    delays.min(),

                "payment_count":
                    len(recent_history),

                "on_time_rate":
                    (
                        (delays == 0).mean()
                    ),

                "early_rate":
                    (
                        (delays < 0).mean()
                    ),

                "late_rate":
                    (
                        (delays > 0).mean()
                    ),

                "avg_amount":
                    recent_history[
                        "Amount"
                    ].mean(),

                "label":
                    current["label"]
            })

    return pd.DataFrame(rows)


def train_udhar_model(file_path):

    print(
        "\nLoading Udhar data..."
    )

    df = load_udhar_data(
        file_path
    )

    training_data = (
        create_training_data(df)
    )

    if len(training_data) < 10:

        raise ValueError(
            "Not enough payment history "
            "to train the Udhar model. "
            "Please provide more historical "
            "customer payment records."
        )

    X = training_data[
        FEATURES
    ]

    y = training_data[
        "label"
    ]

    print(
        f"Training using "
        f"{len(training_data)} payment records..."
    )

    model = RandomForestClassifier(

        n_estimators=200,

        max_depth=6,

        random_state=42,

        class_weight="balanced"
    )

    model.fit(
        X,
        y
    )

    joblib.dump(
    model,
    MODELS_DIR / "udhar_model.pkl"
)

    print(
        "\nUDHAR MODEL TRAINED SUCCESSFULLY!"
    )

    print(
        "Saved as: models/udhar_model.pkl"
    )

    return model


def create_customer_features(df):

    paid = df.dropna(
        subset=["Payment_Date"]
    ).copy()

    paid = calculate_delay(
        paid
    )

    rows = []

    for customer_id, group in paid.groupby(
        "Customer_ID"
    ):

        # Only recent 3 months
        recent_history = (
            get_last_three_months(
                group
            )
        )

        if recent_history.empty:
            continue

        delays = recent_history[
            "delay"
        ]

        rows.append({

            "Customer_ID":
                customer_id,

            "avg_delay":
                delays.mean(),

            "last_delay":
                delays.iloc[-1],

            "max_delay":
                delays.max(),

            "min_delay":
                delays.min(),

            "payment_count":
                len(recent_history),

            "on_time_rate":
                (
                    (delays == 0).mean()
                ),

            "early_rate":
                (
                    (delays < 0).mean()
                ),

            "late_rate":
                (
                    (delays > 0).mean()
                ),

            "avg_amount":
                recent_history[
                    "Amount"
                ].mean()
        })

    return pd.DataFrame(rows)


def predict_customers(file_path):

    df = load_udhar_data(
        file_path
    )

    model = joblib.load(
    MODELS_DIR / "udhar_model.pkl"
)

    customer_features = (
        create_customer_features(
            df
        )
    )

    if customer_features.empty:
        return pd.DataFrame()

    X = customer_features[
        FEATURES
    ]

    predictions = model.predict(
        X
    )

    probabilities = model.predict_proba(
        X
    )

    confidence = (
        probabilities.max(axis=1)
        * 100
    )

    customer_features[
        "Predicted_Behavior"
    ] = predictions

    customer_features[
        "Confidence"
    ] = confidence.round(2)

    outstanding = []

    for customer_id in customer_features[
        "Customer_ID"
    ]:

        customer_transactions = df[
            df["Customer_ID"]
            == customer_id
        ]

        unpaid = customer_transactions[
            customer_transactions[
                "Payment_Date"
            ].isna()
        ]

        amount_due = unpaid[
            "Amount"
        ].sum()

        outstanding.append(
            amount_due
        )

    customer_features[
        "Outstanding"
    ] = outstanding

    return customer_features


if __name__ == "__main__":

    print(
        "udhar_model.py is working."
    )