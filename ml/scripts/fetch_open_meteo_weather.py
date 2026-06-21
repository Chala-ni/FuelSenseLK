"""Fetch hourly weather from Open-Meteo Archive API per district centroid."""

from __future__ import annotations

import argparse
import time
from pathlib import Path

import pandas as pd
import requests

from config import DATA_RAW, END_DATE, START_DATE
from generate_stations import DISTRICT_CENTROIDS

API_URL = "https://archive-api.open-meteo.com/v1/archive"


def fetch_district(district: str, lat: float, lon: float) -> pd.DataFrame:
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": START_DATE[:10],
        "end_date": END_DATE[:10],
        "hourly": "precipitation,temperature_2m",
        "timezone": "Asia/Colombo",
    }
    resp = requests.get(API_URL, params=params, timeout=120)
    resp.raise_for_status()
    data = resp.json()["hourly"]
    return pd.DataFrame({
        "timestamp": pd.to_datetime(data["time"]),
        "district": district,
        "rainfall_mm": data["precipitation"],
        "temperature_c": data["temperature_2m"],
    })


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch Open-Meteo weather per district")
    parser.add_argument("--output", type=Path, default=DATA_RAW / "open_meteo_weather_2025.csv")
    parser.add_argument("--limit", type=int, default=0, help="Limit districts (0=all)")
    args = parser.parse_args()

    districts = list(DISTRICT_CENTROIDS.items())
    if args.limit:
        districts = districts[: args.limit]

    frames = []
    for i, (district, (lat, lon)) in enumerate(districts):
        print(f"[{i + 1}/{len(districts)}] {district} ({lat}, {lon})")
        frames.append(fetch_district(district, lat, lon))
        time.sleep(0.3)

    df = pd.concat(frames, ignore_index=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.output, index=False)
    print(f"Saved {len(df):,} rows -> {args.output}")


if __name__ == "__main__":
    main()
