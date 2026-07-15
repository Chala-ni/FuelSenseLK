"""Re-evaluate saved models on held-out test split (no retraining)."""

from __future__ import annotations

import argparse
import pickle
from pathlib import Path

import numpy as np
import pandas as pd

from config import DATA_RAW, LSTM_CLASSIFICATION_THRESHOLD, LSTM_HORIZONS_HOURS, REPORTS
from ml_utils import classification_metrics, load_splits, stack_station_sequences, write_json

try:
    from tensorflow import keras
except ImportError:
    keras = None

try:
    from prophet import Prophet
except ImportError:
    Prophet = None


def evaluate_lstm(horizon: int, fuel_type: str, station_ids: list[int]) -> dict:
    models_dir = Path(__file__).resolve().parents[1] / "models" / "lstm"
    model_path = models_dir / f"depletion_risk_{horizon}h_best.keras"
    if not model_path.exists():
        model_path = models_dir / f"depletion_risk_{horizon}h.keras"
    scaler_path = models_dir / f"scaler_{horizon}h.pkl"

    model = keras.models.load_model(model_path)
    with scaler_path.open("rb") as f:
        scaler = pickle.load(f)

    _, _, test_df = load_splits(fuel_type=fuel_type)
    X_test, y_test = stack_station_sequences(test_df, station_ids, horizon)
    n, lb, feats = X_test.shape
    flat = scaler.transform(X_test.reshape(-1, feats))
    X_test = flat.reshape(n, lb, feats)

    y_prob = model.predict(X_test, verbose=0).ravel()
    return classification_metrics(y_test, y_prob, LSTM_CLASSIFICATION_THRESHOLD)


def evaluate_prophet(granularity: str, fuel_type: str, station_ids: list[int]) -> list[dict]:
    from ml_utils import mape
    from train_prophet import load_station_series, resample_df

    models_dir = Path(__file__).resolve().parents[1] / "models" / "prophet" / granularity
    results = []
    for sid in station_ids:
        model_path = models_dir / f"station_{sid}_{fuel_type}.pkl"
        if not model_path.exists():
            continue
        with model_path.open("rb") as f:
            model = pickle.load(f)
        _, _, test = load_station_series(sid, fuel_type)
        test = resample_df(test, granularity)
        future = test.rename(columns={"timestamp": "ds"})[
            ["ds", "is_poya_day", "is_school_holiday", "rainfall_mm", "is_price_change_day"]
        ]
        forecast = model.predict(future)
        results.append(
            {
                "station_id": sid,
                "test_mape": round(mape(test["demand_litres"].to_numpy(), forecast["yhat"].to_numpy()), 2),
            }
        )
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate saved ML models on test split")
    parser.add_argument("--model", choices=("lstm", "prophet", "all"), default="all")
    parser.add_argument("--fuel-type", default="petrol_92")
    parser.add_argument("--granularity", default="hourly", choices=("hourly", "daily"))
    args = parser.parse_args()

    stations = pd.read_csv(DATA_RAW / "stations.csv")
    station_ids = sorted(stations["station_id"].astype(int).unique())

    payload = {"fuel_type": args.fuel_type}

    if args.model in ("lstm", "all") and keras:
        payload["lstm"] = {}
        for h in LSTM_HORIZONS_HOURS:
            payload["lstm"][str(h)] = evaluate_lstm(h, args.fuel_type, station_ids)
            print(f"LSTM {h}h test: {payload['lstm'][str(h)]}")

    if args.model in ("prophet", "all") and Prophet:
        rows = evaluate_prophet(args.granularity, args.fuel_type, station_ids)
        avg = float(np.mean([r["test_mape"] for r in rows])) if rows else None
        payload["prophet"] = {"granularity": args.granularity, "avg_test_mape": avg, "per_station": rows}
        print(f"Prophet ({args.granularity}) avg test MAPE: {avg}")

    write_json(REPORTS / "evaluation_rerun.json", payload)
    print(f"Saved -> {REPORTS / 'evaluation_rerun.json'}")


if __name__ == "__main__":
    main()
