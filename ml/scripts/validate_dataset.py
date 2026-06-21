"""Validate synthetic dataset against calibration anchors and bias checks."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from config import (
    ANCHOR_TOLERANCE_PCT,
    ANNUAL_VOLUME_LITRES_ANCHOR,
    DATA_PROCESSED,
    LSTM_HORIZONS_HOURS,
    REPORTS,
    STOCKOUT_THRESHOLD_PCT,
)


def load_dataset(path: Path) -> pd.DataFrame:
    return pd.read_csv(path, parse_dates=["timestamp"])


def validate_volume_anchor(df: pd.DataFrame) -> dict:
    total = df["demand_litres"].sum()
    deviation_pct = abs(total - ANNUAL_VOLUME_LITRES_ANCHOR) / ANNUAL_VOLUME_LITRES_ANCHOR * 100
    return {
        "annual_demand_litres": round(total, 2),
        "anchor_litres": ANNUAL_VOLUME_LITRES_ANCHOR,
        "deviation_pct": round(deviation_pct, 4),
        "within_tolerance": bool(deviation_pct <= ANCHOR_TOLERANCE_PCT),
        "tolerance_pct": ANCHOR_TOLERANCE_PCT,
    }


def validate_dimensions(df: pd.DataFrame) -> dict:
    n_stations = df["station_id"].nunique()
    hours_per_station = df.groupby("station_id")["timestamp"].nunique()
    return {
        "num_stations": int(n_stations),
        "min_hours_per_station": int(hours_per_station.min()),
        "max_hours_per_station": int(hours_per_station.max()),
        "total_records": len(df),
        "meets_200_stations": bool(n_stations >= 200),
        "meets_8760_hours": bool(int(hours_per_station.min()) >= 8760),
    }


def validate_lstm_labels(df: pd.DataFrame) -> dict:
    result = {}
    for h in LSTM_HORIZONS_HOURS:
        col = f"run_out_{h}h"
        if col not in df.columns:
            result[col] = {"present": False}
            continue
        rate = float(df[col].mean())
        result[col] = {
            "present": True,
            "positive_rate": round(rate, 4),
            "positive_count": int(df[col].sum()),
            "healthy_range": 0.03 <= rate <= 0.20 if h == 6 else 0.05 <= rate <= 0.25,
        }
    low_stock_pct = float((df["stock_percentage"] < STOCKOUT_THRESHOLD_PCT).mean())
    result["hours_below_threshold_pct"] = round(low_stock_pct, 4)
    return result


def validate_weather_variation(weather_path: Path) -> dict:
    if not weather_path.exists():
        return {"available": False}
    w = pd.read_csv(weather_path, parse_dates=["timestamp"])
    by_district = w.groupby("district")["rainfall_mm"].mean()
    return {
        "available": True,
        "districts": int(by_district.shape[0]),
        "rainfall_mean_min": round(float(by_district.min()), 4),
        "rainfall_mean_max": round(float(by_district.max()), 4),
        "districts_differ": bool(by_district.max() > by_district.min() * 1.2),
    }


def bias_audit(df: pd.DataFrame) -> dict:
    by_type = df.groupby("station_type")["demand_litres"].sum()
    by_district = df.groupby("district")["demand_litres"].sum().sort_values(ascending=False)
    by_fuel = df.groupby("fuel_type")["demand_litres"].sum()
    weekday = df.groupby("is_weekday")["demand_litres"].mean()

    return {
        "demand_share_by_station_type": (by_type / by_type.sum()).round(4).to_dict(),
        "top_5_districts_by_demand": by_district.head(5).round(2).to_dict(),
        "demand_share_by_fuel_type": (by_fuel / by_fuel.sum()).round(4).to_dict(),
        "weekday_vs_weekend_mean_demand": {
            "weekday": round(float(weekday.get(True, 0)), 2),
            "weekend": round(float(weekday.get(False, 0)), 2),
        },
        "station_factor_std": round(float(df.groupby("station_id")["station_demand_factor"].first().std()), 4),
        "remaining_limitations": [
            "Seasonality from literature assumptions, not measured pump data",
            "Simulated rainfall — Open-Meteo integration planned",
            "No 2022-crisis-scale supply shocks",
            "Delivery disruptions are probabilistic, not from logistics records",
        ],
    }


def load_cbsl_crosscheck() -> dict:
    path = REPORTS / "cbsl_crosscheck.json"
    if not path.exists():
        return {"available": False}
    import json
    return {"available": True, **json.loads(path.read_text(encoding="utf-8"))}


def write_report(results: dict, output: Path) -> None:
    vol = results["volume"]
    lines = [
        "# Dataset Validation Report (v2)",
        "",
        f"**Generated:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        "## Volume Anchor",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Annual demand | {vol['annual_demand_litres']:,.0f} L |",
        f"| Anchor | {vol['anchor_litres']:,.0f} L |",
        f"| Deviation | {vol['deviation_pct']:.2f}% |",
        f"| Within ±{ANCHOR_TOLERANCE_PCT}% | {'Yes' if vol['within_tolerance'] else 'No'} |",
        "",
        "## LSTM Label Health",
        "",
    ]
    for k, v in results.get("lstm_labels", {}).items():
        if isinstance(v, dict) and v.get("present"):
            ok = "OK" if v["healthy_range"] else "LOW/HIGH — review"
            lines.append(f"- **{k}:** {v['positive_rate']*100:.2f}% positive ({ok})")

    lines.extend(["", "## Weather Variation (District-Level)", ""])
    w = results.get("weather", {})
    if w.get("available"):
        lines.append(f"- Districts: {w['districts']}")
        lines.append(f"- Mean rainfall range: {w['rainfall_mean_min']:.3f} – {w['rainfall_mean_max']:.3f} mm")
        lines.append(f"- Districts differ: {'Yes' if w['districts_differ'] else 'No'}")
    lines.extend(["", "## Weekday vs Weekend Demand", ""])
    wd = results["bias"]["weekday_vs_weekend_mean_demand"]
    lines.append(f"- Weekday mean: {wd['weekday']:.2f} L/hr")
    lines.append(f"- Weekend mean: {wd['weekend']:.2f} L/hr")
    lines.extend(["", "## CBSL Import Cross-Check", ""])
    cbsl = results.get("cbsl", {})
    if cbsl.get("available") and "pearson_correlation" in cbsl:
        lines.append(f"- Pearson r (monthly shape): {cbsl['pearson_correlation']}")
        lines.append(f"- Acceptable (r ≥ 0.5): {'Yes' if cbsl.get('correlation_acceptable') else 'No'}")
    else:
        lines.append("- Run `python scripts/crosscheck_cbsl.py` first")
    lines.extend([
        "",
        "## Validation Charts",
        "",
        "See `ml/reports/charts/` for station type, hourly profile, monthly trend, weekday/weekend, LSTM labels.",
        "",
        "## Methodology",
        "",
        "See `ml/docs/dataset_design.md` for full assumptions.",
    ])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate synthetic dataset")
    parser.add_argument("--input", type=Path, default=DATA_PROCESSED / "synthetic_station_hours.csv")
    parser.add_argument("--report", type=Path, default=REPORTS / "dataset_validation.md")
    args = parser.parse_args()

    df = load_dataset(args.input)
    results = {
        "volume": validate_volume_anchor(df),
        "dimensions": validate_dimensions(df),
        "lstm_labels": validate_lstm_labels(df),
        "weather": validate_weather_variation(DATA_PROCESSED / "weather.csv"),
        "cbsl": load_cbsl_crosscheck(),
        "bias": bias_audit(df),
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    json_path = REPORTS / "dataset_validation.json"
    json_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    write_report(results, args.report)

    print(f"Validation -> {args.report}")
    print(f"Volume OK: {results['volume']['within_tolerance']}")
    for h in LSTM_HORIZONS_HOURS:
        col = f"run_out_{h}h"
        if col in results["lstm_labels"] and results["lstm_labels"][col].get("present"):
            print(f"  {col}: {results['lstm_labels'][col]['positive_rate']*100:.2f}% positive")


if __name__ == "__main__":
    main()
