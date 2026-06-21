"""Train LSTM depletion risk classifier (Sprint 2)."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

from config import DATA_SPLITS, LSTM_AUC_PROPOSAL, LSTM_HORIZONS_HOURS, LSTM_LOOKBACK_HOURS, REPORTS

try:
    from tensorflow import keras
    from tensorflow.keras import layers
except ImportError:
    keras = None


def build_windows(df: pd.DataFrame, horizon: int = 12) -> tuple[np.ndarray, np.ndarray]:
    """Causal features only — past stock + context at time t."""
    df = df.sort_values("timestamp")
    stocks = df["stock_litres"].to_numpy(dtype=np.float32)
    labels = df[f"run_out_{horizon}h"].to_numpy(dtype=np.float32)
    hours = df["hour_of_day"].to_numpy(dtype=np.float32) / 23.0
    rainfall = df["rainfall_mm"].to_numpy(dtype=np.float32)

    X, y = [], []
    for i in range(LSTM_LOOKBACK_HOURS, len(df)):
        window = stocks[i - LSTM_LOOKBACK_HOURS : i]
        feat = np.concatenate([window, [hours[i], rainfall[i]]])
        X.append(feat)
        y.append(labels[i])
    return np.array(X), np.array(y)


def build_model(input_dim: int) -> keras.Model:
    model = keras.Sequential([
        layers.Input(shape=(input_dim,)),
        layers.Dense(64, activation="relu"),
        layers.Dropout(0.2),
        layers.Dense(32, activation="relu"),
        layers.Dense(1, activation="sigmoid"),
    ])
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["AUC"])
    return model


def main() -> None:
    parser = argparse.ArgumentParser(description="Train LSTM depletion model")
    parser.add_argument("--horizon", type=int, default=12, choices=LSTM_HORIZONS_HOURS)
    parser.add_argument("--max-stations", type=int, default=20)
    parser.add_argument("--fuel-type", default="petrol_92")
    args = parser.parse_args()

    if keras is None:
        print("TensorFlow not installed. Run: pip install tensorflow")
        return

    train = pd.read_csv(DATA_SPLITS / "train.csv", parse_dates=["timestamp"])
    station_ids = sorted(train["station_id"].unique())[: args.max_stations]

    all_X, all_y = [], []
    for sid in station_ids:
        sub = train[(train["station_id"] == sid) & (train["fuel_type"] == args.fuel_type)]
        if len(sub) < LSTM_LOOKBACK_HOURS + 100:
            continue
        X, y = build_windows(sub, args.horizon)
        all_X.append(X)
        all_y.append(y)

    X = np.vstack(all_X)
    y = np.concatenate(all_y)
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, shuffle=False)

    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_val = scaler.transform(X_val)

    model = build_model(X_train.shape[1])
    model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=10, batch_size=256, verbose=0)

    y_prob = model.predict(X_val, verbose=0).ravel()
    auc = float(roc_auc_score(y_val, y_prob)) if len(np.unique(y_val)) > 1 else 0.0

    models_dir = Path(__file__).resolve().parents[1] / "models" / "lstm"
    models_dir.mkdir(parents=True, exist_ok=True)
    model.save(models_dir / f"depletion_risk_{args.horizon}h.keras")

    summary = {
        "horizon_hours": args.horizon,
        "stations_used": len(station_ids),
        "fuel_type": args.fuel_type,
        "auc": round(auc, 4),
        "target_auc": LSTM_AUC_PROPOSAL,
        "meets_target": auc >= LSTM_AUC_PROPOSAL,
        "positive_rate": round(float(y.mean()), 4),
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    out = REPORTS / f"lstm_performance_{args.horizon}h.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"AUC ({args.horizon}h): {auc:.4f} (target ≥{LSTM_AUC_PROPOSAL})")
    print(f"Model -> {models_dir}")
    print(f"Report -> {out}")


if __name__ == "__main__":
    main()
