"""
Train Prophet demand forecasting models (Sprint 2 — full pipeline).

- One model per station per fuel type
- Train: Jan-Sep | Val: Oct-Nov | Test: Dec
- Granularity: hourly (production) or daily (planning)
- Metrics: MAPE on val + test, stratified by station type
"""

from __future__ import annotations

import argparse
import pickle
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd

from config import DATA_RAW, DATA_SPLITS, PROPHET_MAPE_PROPOSAL, REPORTS, TRAIN_END_MONTH, VAL_END_MONTH
from ml_utils import mape, set_seed, write_json

try:
    from prophet import Prophet
except ImportError:
    Prophet = None

REGRESSORS = ("is_poya_day", "is_school_holiday", "rainfall_mm", "is_price_change_day")


def load_station_meta() -> pd.DataFrame:
    return pd.read_csv(DATA_RAW / "stations.csv")


def load_station_series(station_id: int, fuel_type: str) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    cols = [
        "station_id",
        "timestamp",
        "fuel_type",
        "demand_litres",
        "is_poya_day",
        "is_school_holiday",
        "rainfall_mm",
        "is_price_change_day",
        "month",
    ]
    frames = []
    for split in ("train", "val", "test"):
        path = DATA_SPLITS / f"{split}.csv"
        df = pd.read_csv(path, usecols=cols, parse_dates=["timestamp"])
        df = df[(df["station_id"] == station_id) & (df["fuel_type"] == fuel_type)]
        frames.append(df.sort_values("timestamp"))
    return frames[0], frames[1], frames[2]


def resample_df(df: pd.DataFrame, granularity: str) -> pd.DataFrame:
    if granularity == "hourly" or df.empty:
        return df
    return (
        df.set_index("timestamp")
        .resample("D")
        .agg(
            {
                "demand_litres": "sum",
                "is_poya_day": "max",
                "is_school_holiday": "max",
                "rainfall_mm": "sum",
                "is_price_change_day": "max",
            }
        )
        .reset_index()
    )


def train_one_station(
    train: pd.DataFrame,
    val: pd.DataFrame,
    test: pd.DataFrame,
    granularity: str,
) -> tuple[dict, object | None]:
    if Prophet is None:
        raise ImportError("Install prophet: pip install prophet")

    train = resample_df(train, granularity)
    val = resample_df(val, granularity)
    test = resample_df(test, granularity)

    if len(train) < 48 or len(test) < 24:
        return {"skipped": True, "reason": "insufficient_rows"}, None

    prophet_train = train.rename(columns={"timestamp": "ds", "demand_litres": "y"})
    for reg in REGRESSORS:
        prophet_train[reg] = train[reg].astype(float).values

    model = Prophet(
        daily_seasonality=granularity == "hourly",
        weekly_seasonality=True,
        yearly_seasonality=True,
        seasonality_mode="multiplicative",
        changepoint_prior_scale=0.05,
    )
    for reg in REGRESSORS:
        model.add_regressor(reg)

    model.fit(prophet_train[["ds", "y", *REGRESSORS]])

    metrics = {
        "train_rows": len(train),
        "val_rows": len(val),
        "test_rows": len(test),
        "granularity": granularity,
    }

    for split_name, split_df in (("val", val), ("test", test)):
        if split_df.empty:
            metrics[f"{split_name}_mape"] = None
            continue
        future = split_df.rename(columns={"timestamp": "ds"})[["ds", *REGRESSORS]]
        forecast = model.predict(future)
        score = mape(split_df["demand_litres"].to_numpy(), forecast["yhat"].to_numpy())
        metrics[f"{split_name}_mape"] = round(score, 2)

    return metrics, model


def main() -> None:
    parser = argparse.ArgumentParser(description="Train Prophet models (full pipeline)")
    parser.add_argument("--fuel-type", default="petrol_92")
    parser.add_argument("--granularity", default="hourly", choices=("hourly", "daily"))
    parser.add_argument("--max-stations", type=int, default=0, help="0 = all 200 stations")
    args = parser.parse_args()

    if Prophet is None:
        raise SystemExit("Prophet not installed. Run: pip install prophet")

    set_seed()
    meta = load_station_meta()
    station_ids = sorted(meta["station_id"].astype(int).unique())
    if args.max_stations > 0:
        station_ids = station_ids[: args.max_stations]

    id_to_type = dict(zip(meta["station_id"].astype(int), meta["station_type"]))

    models_dir = Path(__file__).resolve().parents[1] / "models" / "prophet" / args.granularity
    models_dir.mkdir(parents=True, exist_ok=True)

    per_station = []
    t0 = time.time()

    for i, sid in enumerate(station_ids, 1):
        train, val, test = load_station_series(sid, args.fuel_type)
        metrics, model = train_one_station(train, val, test, args.granularity)
        if metrics.get("skipped"):
            continue
        metrics["station_id"] = int(sid)
        metrics["station_type"] = id_to_type.get(int(sid), "unknown")
        metrics["fuel_type"] = args.fuel_type
        per_station.append(metrics)

        if model is not None:
            with (models_dir / f"station_{sid}_{args.fuel_type}.pkl").open("wb") as f:
                pickle.dump(model, f)

        if i % 10 == 0 or i == len(station_ids):
            avg_test = float(np.nanmean([m["test_mape"] for m in per_station]))
            print(f"  [{i}/{len(station_ids)}] stations done — running avg test MAPE: {avg_test:.2f}%")

    by_type: dict[str, list[float]] = defaultdict(list)
    for m in per_station:
        if m.get("test_mape") is not None:
            by_type[m["station_type"]].append(m["test_mape"])

    type_summary = {}
    for stype in sorted(by_type):
        stations_of_type = [m for m in per_station if m["station_type"] == stype]
        type_summary[stype] = {
            "count": len(by_type[stype]),
            "avg_test_mape": round(float(np.mean(by_type[stype])), 2),
            "avg_val_mape": round(
                float(np.mean([m["val_mape"] for m in stations_of_type if m.get("val_mape") is not None])),
                2,
            ),
        }

    avg_val = float(np.nanmean([m["val_mape"] for m in per_station]))
    avg_test = float(np.nanmean([m["test_mape"] for m in per_station]))

    summary = {
        "model": "prophet",
        "fuel_type": args.fuel_type,
        "granularity": args.granularity,
        "stations_trained": len(per_station),
        "stations_requested": len(station_ids),
        "temporal_split": {
            "train": f"months 1-{TRAIN_END_MONTH}",
            "val": f"months {TRAIN_END_MONTH + 1}-{VAL_END_MONTH}",
            "test": f"month {VAL_END_MONTH + 1}+",
        },
        "regressors": list(REGRESSORS),
        "avg_val_mape": round(avg_val, 2),
        "avg_test_mape": round(avg_test, 2),
        "target_mape": PROPHET_MAPE_PROPOSAL * 100,
        "meets_target_test": bool(avg_test <= PROPHET_MAPE_PROPOSAL * 100),
        "by_station_type": type_summary,
        "per_station": per_station,
        "train_seconds": round(time.time() - t0, 1),
        "note": "Prophet uses Stan MCMC — no batch size/epochs hyperparameters",
    }

    out = REPORTS / f"prophet_performance_{args.granularity}.json"
    write_json(out, summary)
    write_json(REPORTS / "prophet_performance.json", summary)
    print(f"\nVal MAPE: {avg_val:.2f}% | Test MAPE: {avg_test:.2f}% (target <={PROPHET_MAPE_PROPOSAL*100}%)")
    print(f"Report -> {out}")


if __name__ == "__main__":
    main()
