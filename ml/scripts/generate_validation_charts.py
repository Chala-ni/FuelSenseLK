"""Generate validation charts for Sprint 1 dataset report."""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from config import DATA_PROCESSED, REPORTS


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate validation charts")
    parser.add_argument("--input", type=Path, default=DATA_PROCESSED / "synthetic_station_hours.csv")
    parser.add_argument("--out-dir", type=Path, default=REPORTS / "charts")
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(args.input, parse_dates=["timestamp"])

    # 1. Demand by station type
    by_type = df.groupby("station_type")["demand_litres"].sum()
    fig, ax = plt.subplots(figsize=(8, 5))
    by_type.plot(kind="bar", ax=ax, color=["#2ecc71", "#3498db", "#e74c3c", "#95a5a6"])
    ax.set_title("Annual Demand by Station Type")
    ax.set_ylabel("Litres")
    ax.set_xlabel("Station Type")
    fig.tight_layout()
    fig.savefig(args.out_dir / "demand_by_station_type.png", dpi=120)
    plt.close()

    # 2. Hourly profile (weekday average)
    hourly = df.groupby("hour_of_day")["demand_litres"].mean()
    fig, ax = plt.subplots(figsize=(10, 4))
    hourly.plot(ax=ax, color="#2980b9")
    ax.set_title("Mean Hourly Demand Profile (Network)")
    ax.set_xlabel("Hour of Day")
    ax.set_ylabel("Mean Litres / Hour")
    fig.tight_layout()
    fig.savefig(args.out_dir / "hourly_demand_profile.png", dpi=120)
    plt.close()

    # 3. Monthly demand trend
    df["month"] = df["timestamp"].dt.to_period("M")
    monthly = df.groupby("month")["demand_litres"].sum()
    fig, ax = plt.subplots(figsize=(10, 4))
    monthly.plot(ax=ax, marker="o", color="#8e44ad")
    ax.set_title("Monthly Synthetic Demand")
    ax.set_ylabel("Litres")
    fig.tight_layout()
    fig.savefig(args.out_dir / "monthly_demand_trend.png", dpi=120)
    plt.close()

    # 4. Weekday vs weekend
    wd = df.groupby("is_weekday")["demand_litres"].mean()
    fig, ax = plt.subplots(figsize=(5, 4))
    wd.index = ["Weekend", "Weekday"]
    wd.plot(kind="bar", ax=ax, color=["#e67e22", "#27ae60"])
    ax.set_title("Mean Demand: Weekday vs Weekend")
    ax.set_ylabel("Litres / Hour")
    fig.tight_layout()
    fig.savefig(args.out_dir / "weekday_vs_weekend.png", dpi=120)
    plt.close()

    # 5. LSTM label rates
    labels = [c for c in df.columns if c.startswith("run_out_")]
    rates = [df[c].mean() * 100 for c in labels]
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.bar([c.replace("run_out_", "") for c in labels], rates, color="#c0392b")
    ax.set_title("LSTM Stock-Out Label Positive Rate (%)")
    ax.set_xlabel("Horizon")
    fig.tight_layout()
    fig.savefig(args.out_dir / "lstm_label_rates.png", dpi=120)
    plt.close()

    print(f"Charts saved -> {args.out_dir} ({5} files)")


if __name__ == "__main__":
    main()
