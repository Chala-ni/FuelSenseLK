"""Cross-check synthetic monthly demand against CBSL petroleum import trends."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from config import DATA_PROCESSED, DATA_RAW, REPORTS


def load_synthetic_monthly() -> pd.Series:
    path = DATA_PROCESSED / "synthetic_station_hours.csv"
    df = pd.read_csv(path, parse_dates=["timestamp"], usecols=["timestamp", "demand_litres"])
    df["month"] = df["timestamp"].dt.to_period("M").astype(str)
    return df.groupby("month")["demand_litres"].sum()


def load_cbsl() -> pd.Series:
    path = DATA_RAW / "cbsl_petroleum_imports_monthly.csv"
    df = pd.read_csv(path)
    df["month"] = pd.to_datetime(df["month"]).dt.to_period("M").astype(str)
    return df.set_index("month")["petroleum_imports_usd_mn"]


def crosscheck() -> dict:
    synthetic = load_synthetic_monthly()
    cbsl = load_cbsl()
    # Compare 2025 synthetic year against CBSL 2025 months
    synthetic_2025 = synthetic[[m for m in synthetic.index if m.startswith("2025")]]
    common = synthetic_2025.index.intersection(cbsl.index)
    if len(common) < 3:
        return {"error": "Insufficient overlapping months", "overlap": len(common)}

    s = synthetic_2025.loc[common].astype(float)
    c = cbsl.loc[common].astype(float)
    correlation = float(np.corrcoef(s, c)[0, 1])
    s_norm = (s - s.mean()) / s.std()
    c_norm = (c - c.mean()) / c.std()
    mape_shape = float((abs(s_norm - c_norm) / (abs(c_norm) + 1e-9)).mean() * 100)

    return {
        "overlapping_months": int(len(common)),
        "pearson_correlation": round(correlation, 4),
        "correlation_acceptable": correlation >= 0.5,
        "shape_mape_pct": round(mape_shape, 2),
        "note": (
            "Compares normalised monthly demand shape vs CBSL import USD trend. "
            "Absolute volumes differ (imports vs retail dispense) — correlation of pattern is the valid check."
        ),
        "monthly_comparison": {
            m: {"synthetic_litres": round(float(synthetic[m]), 0), "cbsl_usd_mn": float(cbsl[m])}
            for m in sorted(common)[:12]
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="CBSL petroleum import cross-check")
    parser.add_argument("--output", type=Path, default=REPORTS / "cbsl_crosscheck.json")
    args = parser.parse_args()

    result = crosscheck()
    REPORTS.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"CBSL cross-check -> {args.output}")
    if "pearson_correlation" in result:
        print(f"  Pearson r = {result['pearson_correlation']} ({'OK' if result['correlation_acceptable'] else 'review'})")


if __name__ == "__main__":
    main()
