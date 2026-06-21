"""Train Prophet demand forecasting models (Sprint 2)."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from config import DATA_SPLITS, LSTM_HORIZONS_HOURS, PROPHET_MAPE_PROPOSAL, REPORTS

try:
    from prophet import Prophet
except ImportError:
    Prophet = None


def mape(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    mask = y_true > 0
    if not mask.any():
        return float("nan")
    return float(np.mean(np.abs((y_true[mask] - y_pred[mask]) / y_true[mask])) * 100)


def load_series(station_id: int, fuel_type: str) -> pd.DataFrame:
    train = pd.read_csv(DATA_SPLITS / "train.csv", parse_dates=["timestamp"])
    test = pd.read_csv(DATA_SPLITS / "test.csv", parse_dates=["timestamp"])
    df = pd.concat([train, test], ignore_index=True)
    df = df[(df["station_id"] == station_id) & (df["fuel_type"] == fuel_type)]
    return df.sort_values("timestamp")


def train_one(df: pd.DataFrame) -> tuple[dict, object | None]:
    if Prophet is None:
        raise ImportError("Install prophet: pip install prophet")

    train = df[df["timestamp"].dt.month <= 9].copy()
    test = df[df["timestamp"].dt.month == 12].copy()

    prophet_df = train.rename(columns={"timestamp": "ds", "demand_litres": "y"})[["ds", "y"]]
    prophet_df["is_poya_day"] = train["is_poya_day"].astype(int).values
    prophet_df["is_school_holiday"] = train["is_school_holiday"].astype(int).values
    prophet_df["rainfall_mm"] = train["rainfall_mm"].values

    model = Prophet(daily_seasonality=True, weekly_seasonality=True, yearly_seasonality=True)
    for reg in ("is_poya_day", "is_school_holiday", "rainfall_mm"):
        model.add_regressor(reg)

    model.fit(prophet_df)

    future = test.rename(columns={"timestamp": "ds"})[["ds", "is_poya_day", "is_school_holiday", "rainfall_mm"]]
    forecast = model.predict(future)
    score = mape(test["demand_litres"].to_numpy(), forecast["yhat"].to_numpy())
    return {"mape": round(score, 2), "test_rows": len(test)}, model


def main() -> None:
    parser = argparse.ArgumentParser(description="Train Prophet models")
    parser.add_argument("--max-stations", type=int, default=5, help="Stations to train (pilot)")
    parser.add_argument("--fuel-type", default="petrol_92")
    args = parser.parse_args()

    if Prophet is None:
        print("Prophet not installed. Run: pip install prophet")
        return

    train = pd.read_csv(DATA_SPLITS / "train.csv", usecols=["station_id"])
    station_ids = sorted(train["station_id"].unique())[: args.max_stations]

    results = []
    models_dir = Path(__file__).resolve().parents[1] / "models" / "prophet"
    models_dir.mkdir(parents=True, exist_ok=True)

    for sid in station_ids:
        df = load_series(sid, args.fuel_type)
        metrics, model = train_one(df)
        metrics["station_id"] = int(sid)
        metrics["fuel_type"] = args.fuel_type
        results.append(metrics)
        import pickle
        with (models_dir / f"station_{sid}_{args.fuel_type}.pkl").open("wb") as f:
            pickle.dump(model, f)
        print(f"  Station {sid}: MAPE={metrics['mape']}%")

    avg_mape = float(np.nanmean([r["mape"] for r in results]))
    summary = {
        "stations_trained": len(results),
        "fuel_type": args.fuel_type,
        "avg_mape": round(avg_mape, 2),
        "target_mape": PROPHET_MAPE_PROPOSAL * 100,
        "meets_target": avg_mape <= PROPHET_MAPE_PROPOSAL * 100,
        "per_station": results,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    out = REPORTS / "prophet_performance.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"\nAvg MAPE: {avg_mape:.2f}% (target ≤{PROPHET_MAPE_PROPOSAL*100}%)")
    print(f"Report -> {out}")


if __name__ == "__main__":
    main()
