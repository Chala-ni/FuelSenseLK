"""Train ARIMA baseline on same temporal splits (academic comparison)."""

from __future__ import annotations

import argparse
import json
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

from config import DATA_RAW, DATA_SPLITS, REPORTS, TRAIN_END_MONTH, VAL_END_MONTH
from ml_utils import mape, set_seed, write_json

warnings.filterwarnings("ignore")

try:
    from statsmodels.tsa.arima.model import ARIMA
except ImportError:
    ARIMA = None


def load_series(station_id: int, fuel_type: str) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    cols = ["station_id", "timestamp", "fuel_type", "demand_litres", "month"]
    out = []
    for split in ("train", "val", "test"):
        df = pd.read_csv(DATA_SPLITS / f"{split}.csv", usecols=cols, parse_dates=["timestamp"])
        out.append(df[(df["station_id"] == station_id) & (df["fuel_type"] == fuel_type)].sort_values("timestamp"))
    return out[0], out[1], out[2]


def fit_arima(train: pd.DataFrame, test: pd.DataFrame) -> dict:
    if len(train) < 168 or len(test) < 24:
        return {"skipped": True}
    series = train.set_index("timestamp")["demand_litres"].astype(float)
    test_series = test.set_index("timestamp")["demand_litres"].astype(float)
    model = ARIMA(series, order=(2, 1, 2))
    fitted = model.fit()
    forecast = fitted.forecast(steps=len(test_series))
    return {
        "test_mape": round(mape(test_series.to_numpy(), forecast.to_numpy()), 2),
        "train_rows": len(train),
        "test_rows": len(test),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="ARIMA baseline")
    parser.add_argument("--fuel-type", default="petrol_92")
    parser.add_argument("--max-stations", type=int, default=0, help="0 = all stations")
    args = parser.parse_args()

    if ARIMA is None:
        raise SystemExit("statsmodels not installed")

    set_seed()
    meta = pd.read_csv(DATA_RAW / "stations.csv")
    station_ids = sorted(meta["station_id"].astype(int).unique())
    if args.max_stations > 0:
        station_ids = station_ids[: args.max_stations]

    results = []
    for sid in station_ids:
        train, val, test = load_series(sid, args.fuel_type)
        metrics = fit_arima(train, test)
        if metrics.get("skipped"):
            continue
        metrics["station_id"] = int(sid)
        results.append(metrics)
        print(f"  Station {sid}: test MAPE={metrics['test_mape']}%")

    avg = float(np.mean([r["test_mape"] for r in results])) if results else float("nan")
    summary = {
        "model": "ARIMA(2,1,2)",
        "fuel_type": args.fuel_type,
        "stations_trained": len(results),
        "temporal_split": {
            "train": f"months 1-{TRAIN_END_MONTH}",
            "test": f"month {VAL_END_MONTH + 1}+",
        },
        "avg_test_mape": round(avg, 2),
        "per_station": results,
        "note": "Academic baseline only — not deployed",
    }
    write_json(REPORTS / "arima_baseline.json", summary)
    print(f"Avg test MAPE: {avg:.2f}%")


if __name__ == "__main__":
    main()
