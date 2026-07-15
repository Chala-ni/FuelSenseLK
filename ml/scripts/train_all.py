"""
Run all Sprint 2 ML training jobs **one at a time** (CPU-safe).

Do NOT run train_lstm.py, train_prophet.py, and train_arima.py in parallel.

Usage:
    cd ml/scripts
    python train_all.py                  # full pipeline
    python train_all.py --only lstm      # single model
    python train_all.py --only prophet --prophet-granularity daily
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent


def run_step(name: str, cmd: list[str]) -> None:
    print("\n" + "=" * 60)
    print(f"START: {name}")
    print(" ".join(cmd))
    print("=" * 60 + "\n")
    t0 = time.time()
    result = subprocess.run(cmd, cwd=SCRIPTS)
    elapsed = time.time() - t0
    if result.returncode != 0:
        raise SystemExit(f"{name} failed (exit {result.returncode}) after {elapsed:.0f}s")
    print(f"\nDONE: {name} in {elapsed / 60:.1f} min\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sequential ML training (one job at a time)")
    parser.add_argument(
        "--only",
        choices=("lstm", "prophet", "arima", "reports"),
        help="Run a single step instead of the full pipeline",
    )
    parser.add_argument("--fuel-type", default="petrol_92")
    parser.add_argument("--prophet-granularity", default="hourly", choices=("hourly", "daily"))
    parser.add_argument("--prophet-max-stations", type=int, default=0, help="0 = all 200")
    parser.add_argument("--skip-reports", action="store_true")
    args = parser.parse_args()

    py = sys.executable
    prophet_cmd = [py, "train_prophet.py", "--fuel-type", args.fuel_type, "--granularity", args.prophet_granularity]
    if args.prophet_max_stations > 0:
        prophet_cmd += ["--max-stations", str(args.prophet_max_stations)]

    steps = {
        "lstm": [py, "train_lstm.py", "--fuel-type", args.fuel_type, "--horizons", "6,12,24"],
        "prophet": prophet_cmd,
        "arima": [py, "train_arima.py", "--fuel-type", args.fuel_type],
        "reports": [py, "generate_ml_reports.py"],
    }

    order = ("lstm", "prophet", "arima", "reports") if not args.skip_reports else ("lstm", "prophet", "arima")

    if args.only:
        run_step(args.only, steps[args.only])
        if args.only != "reports" and not args.skip_reports:
            run_step("reports", steps["reports"])
        return

    print("FuelSense LK — sequential training (CPU-safe, one model at a time)")
    for key in order:
        run_step(key, steps[key])
    print("All training complete.")


if __name__ == "__main__":
    main()
