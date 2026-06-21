"""Create temporal train/val/test splits with leakage audit (lecturer amendment)."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from config import DATA_PROCESSED, DATA_SPLITS, LSTM_LOOKBACK_HOURS, LSTM_HORIZONS_HOURS, REPORTS, TRAIN_END_MONTH, VAL_END_MONTH


def load_dataset(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["timestamp"])
    df["month"] = df["timestamp"].dt.month
    return df


def temporal_split(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Strict temporal split — no random shuffle across time."""
    train = df[df["month"] <= TRAIN_END_MONTH].copy()
    val = df[(df["month"] > TRAIN_END_MONTH) & (df["month"] <= VAL_END_MONTH)].copy()
    test = df[df["month"] > VAL_END_MONTH].copy()
    return train, val, test


def audit_leakage(train: pd.DataFrame, val: pd.DataFrame, test: pd.DataFrame) -> dict:
    """Verify no temporal overlap between splits."""
    checks = {
        "train_max_timestamp": str(train["timestamp"].max()),
        "val_min_timestamp": str(val["timestamp"].min()),
        "val_max_timestamp": str(val["timestamp"].max()),
        "test_min_timestamp": str(test["timestamp"].min()),
        "no_train_val_overlap": train["timestamp"].max() < val["timestamp"].min(),
        "no_val_test_overlap": val["timestamp"].max() < test["timestamp"].min(),
        "lstm_lookback_hours": LSTM_LOOKBACK_HOURS,
        "lstm_horizons_hours": list(LSTM_HORIZONS_HOURS),
        "lstm_causal_rule": "Features use stock/demand at t and earlier only; labels use future stock-out within horizon",
        "prophet_regressor_rule": "Regressors must be known at forecast origin; no same-timestamp target in features",
        "random_shuffle_used": False,
    }
    checks["all_passed"] = checks["no_train_val_overlap"] and checks["no_val_test_overlap"]
    return checks


def main() -> None:
    parser = argparse.ArgumentParser(description="Split dataset with leakage audit")
    parser.add_argument(
        "--input",
        type=Path,
        default=DATA_PROCESSED / "synthetic_station_hours.csv",
    )
    parser.add_argument("--out-dir", type=Path, default=DATA_SPLITS)
    args = parser.parse_args()

    df = load_dataset(args.input)
    train, val, test = temporal_split(df)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    train.to_csv(args.out_dir / "train.csv", index=False)
    val.to_csv(args.out_dir / "val.csv", index=False)
    test.to_csv(args.out_dir / "test.csv", index=False)

    audit = audit_leakage(train, val, test)
    audit_path = args.out_dir / "leakage_audit.json"
    audit_path.write_text(json.dumps(audit, indent=2), encoding="utf-8")

    REPORTS.mkdir(parents=True, exist_ok=True)

    print(f"Train: {len(train):,} rows (months 1–{TRAIN_END_MONTH})")
    print(f"Val:   {len(val):,} rows (months {TRAIN_END_MONTH + 1}–{VAL_END_MONTH})")
    print(f"Test:  {len(test):,} rows (month {VAL_END_MONTH + 1}+)")
    print(f"Leakage audit -> {audit_path}")
    print(f"All checks passed: {audit['all_passed']}")


if __name__ == "__main__":
    main()
