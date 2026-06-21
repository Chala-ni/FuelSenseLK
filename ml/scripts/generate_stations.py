"""Generate synthetic fuel station seed data for 200 stations."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from config import (
    DATA_RAW,
    FUEL_TYPES,
    NUM_STATIONS,
    RANDOM_SEED,
    STATION_FACTOR_MAX,
    STATION_FACTOR_MIN,
    STATION_TYPE_WEIGHTS,
    TANK_CAPACITY,
)

DISTRICT_CENTROIDS = {
    "Colombo": (6.9271, 79.8612), "Gampaha": (7.0873, 80.0144),
    "Kalutara": (6.5854, 79.9607), "Kandy": (7.2906, 80.6337),
    "Galle": (6.0535, 80.2210), "Matara": (5.9549, 80.5550),
    "Hambantota": (6.1241, 81.1185), "Jaffna": (9.6615, 80.0255),
    "Kurunegala": (7.4863, 80.3623), "Anuradhapura": (8.3114, 80.4037),
    "Badulla": (6.9934, 81.0550), "Ratnapura": (6.6828, 80.3992),
    "Trincomalee": (8.5874, 81.2152), "Batticaloa": (7.7102, 81.6924),
    "Ampara": (7.2916, 81.6724), "Polonnaruwa": (7.9403, 81.0188),
    "Monaragala": (6.8728, 81.3507), "Puttalam": (8.0408, 79.8394),
    "Mannar": (8.9810, 79.9044), "Vavuniya": (8.7514, 80.4971),
    "Mullaitivu": (9.2671, 80.8142), "Kilinochchi": (9.3803, 80.3769),
    "Nuwara Eliya": (6.9497, 80.7891), "Kegalle": (7.2513, 80.3464),
}


def load_districts() -> pd.DataFrame:
    return pd.read_csv(DATA_RAW / "districts.csv")


def generate_stations(n: int = NUM_STATIONS, seed: int = RANDOM_SEED) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    districts = load_districts()
    district_names = districts["district"].tolist()
    weights = districts["weight"].to_numpy(dtype=float)
    district_weights = weights / weights.sum()

    assigned_districts = rng.choice(district_names, size=n, p=district_weights)
    types = list(STATION_TYPE_WEIGHTS.keys())
    type_weights = list(STATION_TYPE_WEIGHTS.values())
    station_types = rng.choice(types, size=n, p=type_weights)

    rows = []
    for i, (district, station_type) in enumerate(zip(assigned_districts, station_types)):
        base_lat, base_lng = DISTRICT_CENTROIDS[district]
        fuel_types = list(FUEL_TYPES) if station_type != "rural" else ["petrol_92", "auto_diesel"]
        rows.append({
            "station_id": i + 1,
            "name": f"FuelSense Station {i + 1:03d}",
            "district": district,
            "station_type": station_type,
            "latitude": round(base_lat + rng.normal(0, 0.08), 6),
            "longitude": round(base_lng + rng.normal(0, 0.08), 6),
            "tank_capacity_litres": TANK_CAPACITY[station_type],
            "fuel_types": ",".join(fuel_types),
            "station_demand_factor": round(rng.uniform(STATION_FACTOR_MIN, STATION_FACTOR_MAX), 4),
            "is_active": True,
        })

    return pd.DataFrame(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate station seed data")
    parser.add_argument("--output", type=Path, default=DATA_RAW / "stations.csv")
    parser.add_argument("--count", type=int, default=NUM_STATIONS)
    args = parser.parse_args()

    df = generate_stations(n=args.count)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.output, index=False)
    print(f"Generated {len(df)} stations -> {args.output}")
    print(df["station_type"].value_counts().to_string())
    print(f"Demand factor range: {df['station_demand_factor'].min():.3f} – {df['station_demand_factor'].max():.3f}")


if __name__ == "__main__":
    main()
