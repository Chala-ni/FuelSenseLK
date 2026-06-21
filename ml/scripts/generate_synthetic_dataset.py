"""Generate synthetic per-station hourly fuel dataset (dataset_design.md v2)."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from config import (
    ANNUAL_VOLUME_LITRES_ANCHOR,
    DATA_PROCESSED,
    DATA_RAW,
    DELIVERY_DELAY_DAYS,
    DELIVERY_DELAY_PROB,
    DELIVERY_INTERVAL_BY_TYPE,
    DEMAND_SURGE_MULTIPLIER,
    DEMAND_SURGE_PROB,
    DIESEL_FUEL_TYPES,
    DISTRICT_RAINFALL_FACTOR,
    END_DATE,
    FUEL_TYPE_SHARE,
    HOURLY_PROFILE_DIESEL,
    HOURLY_PROFILE_PETROL,
    LSTM_HORIZONS_HOURS,
    NOISE_SIGMA_PCT,
    POYA_DEMAND_REDUCTION,
    PRE_PRICE_CHANGE_SURGE,
    PRICE_CHANGE_DAY_REDUCTION,
    RAINFALL_DEMAND_REDUCTION,
    RAINFALL_THRESHOLD_MM,
    RANDOM_SEED,
    SCHOOL_HOLIDAY_REDUCTION,
    START_DATE,
    STOCKOUT_THRESHOLD_PCT,
    TANK_CAPACITY,
    WEEKDAY_MULTIPLIER,
    WEEKEND_MULTIPLIER,
    STATION_VOLUME_WEIGHT,
)


def load_holidays() -> pd.DataFrame:
    df = pd.read_csv(DATA_RAW / "holidays_sri_lanka_2025.csv", parse_dates=["date"])
    df["date"] = df["date"].dt.date
    return df


def load_stations() -> pd.DataFrame:
    path = DATA_RAW / "stations.csv"
    if not path.exists():
        raise FileNotFoundError(f"Run generate_stations.py first. Missing: {path}")
    return pd.read_csv(path)


def normalized_profile(profile: dict[int, float]) -> np.ndarray:
    arr = np.array([profile[h] for h in range(24)], dtype=np.float64)
    return arr / arr.sum() * 24


PETROL_PROFILE = normalized_profile(HOURLY_PROFILE_PETROL)
DIESEL_PROFILE = normalized_profile(HOURLY_PROFILE_DIESEL)


def simulate_district_weather(
    timestamps: pd.DatetimeIndex,
    districts: list[str],
    rng: np.random.Generator,
) -> pd.DataFrame:
    rows = []
    monsoon = np.where(timestamps.month.isin([5, 6, 7, 8, 9]), 2.5, 1.0)
    for district in districts:
        factor = DISTRICT_RAINFALL_FACTOR.get(district, 1.0)
        rainfall = np.clip(rng.exponential(0.3, len(timestamps)) * monsoon * factor, 0, 50)
        base_temp = 20.0 if district in ("Nuwara Eliya", "Badulla") else 28.0
        temp = base_temp + rng.normal(0, 1.5, len(timestamps))
        for i, ts in enumerate(timestamps):
            rows.append({
                "timestamp": ts, "district": district,
                "rainfall_mm": round(float(rainfall[i]), 4),
                "temperature_c": round(float(temp[i]), 2),
            })
    return pd.DataFrame(rows)


def build_calendar_arrays(timestamps: pd.DatetimeIndex, holidays: pd.DataFrame) -> dict[str, np.ndarray]:
    poya = set(holidays.loc[holidays["holiday_type"] == "poya", "date"])
    school = set(holidays.loc[holidays["holiday_type"] == "school_holiday", "date"])
    price_chg = set(holidays.loc[holidays["holiday_type"] == "price_change", "date"])
    pre_price = {(pd.Timestamp(d) - pd.Timedelta(days=1)).date() for d in price_chg}
    dates = [ts.date() for ts in timestamps]

    is_weekday = timestamps.dayofweek < 5
    mult = np.where(is_weekday, WEEKDAY_MULTIPLIER, WEEKEND_MULTIPLIER).astype(np.float64)
    mult = np.where([d in poya for d in dates], mult * (1 - POYA_DEMAND_REDUCTION), mult)
    mult = np.where([d in school for d in dates], mult * (1 - SCHOOL_HOLIDAY_REDUCTION), mult)
    mult = np.where([d in pre_price for d in dates], mult * (1 + PRE_PRICE_CHANGE_SURGE), mult)
    mult = np.where([d in price_chg for d in dates], mult * (1 - PRICE_CHANGE_DAY_REDUCTION), mult)

    return {
        "hours": timestamps.hour.to_numpy(),
        "day_of_week": timestamps.dayofweek.to_numpy(),
        "is_weekday": is_weekday,
        "is_poya": np.array([d in poya for d in dates]),
        "is_school": np.array([d in school for d in dates]),
        "is_price_chg": np.array([d in price_chg for d in dates]),
        "is_pre_price": np.array([d in pre_price for d in dates]),
        "day_of_year": timestamps.dayofyear.to_numpy(),
        "demand_mult_base": mult,
    }


def label_series(stocks: np.ndarray, horizon: int) -> np.ndarray:
    """Stock-out within horizon: currently has stock but will hit zero in next N hours."""
    n = len(stocks)
    labels = np.zeros(n, dtype=np.int8)
    for i in range(n - 1):
        if stocks[i] <= 0:
            continue
        end = min(i + horizon + 1, n)
        if stocks[i + 1 : end].min() <= 0:
            labels[i] = 1
    return labels


def simulate_station_fuel(
    n_hours: int,
    capacity: float,
    hourly_base: float,
    profile: np.ndarray,
    cal: dict[str, np.ndarray],
    rainfall: np.ndarray,
    rng: np.random.Generator,
    del_min: int,
    del_max: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    demand = np.zeros(n_hours)
    stock = np.zeros(n_hours)
    delivery = np.zeros(n_hours)
    stock[0] = capacity * rng.uniform(0.5, 0.85)

    next_del_day = rng.integers(del_min, del_max + 1)
    pending_delay = 0
    noise = np.clip(rng.normal(1.0, NOISE_SIGMA_PCT, n_hours), 0, None)
    surge = rng.random(n_hours) < DEMAND_SURGE_PROB

    for t in range(n_hours):
        h = cal["hours"][t]
        m = cal["demand_mult_base"][t] * noise[t]
        if rainfall[t] > RAINFALL_THRESHOLD_MM:
            m *= 1 - RAINFALL_DEMAND_REDUCTION
        if surge[t]:
            m *= DEMAND_SURGE_MULTIPLIER
        demand[t] = hourly_base * profile[h] * m

        if pending_delay > 0:
            pending_delay -= 1
        elif cal["day_of_year"][t] >= next_del_day:
            if rng.random() < DELIVERY_DELAY_PROB:
                pending_delay = rng.integers(DELIVERY_DELAY_DAYS[0], DELIVERY_DELAY_DAYS[1] + 1)
            else:
                delivery[t] = capacity * rng.uniform(0.60, 1.00)

        prev = stock[t - 1] if t > 0 else stock[0]
        stock[t] = max(min(prev - demand[t] + delivery[t], capacity), 0.0)
        if delivery[t] > 0:
            next_del_day = cal["day_of_year"][t] + rng.integers(del_min, del_max + 1)

    return demand, stock, delivery, stock / capacity * 100


def generate_dataset(seed: int = RANDOM_SEED) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    rng = np.random.default_rng(seed)
    stations = load_stations()
    timestamps = pd.date_range(START_DATE, END_DATE, freq="h")
    n_hours = len(timestamps)
    cal = build_calendar_arrays(timestamps, load_holidays())

    districts = sorted(stations["district"].unique())
    weather_df = simulate_district_weather(timestamps, districts, rng)
    rain_by_district = {
        d: weather_df.loc[weather_df["district"] == d, "rainfall_mm"].to_numpy()
        for d in districts
    }
    temp_by_district = {
        d: weather_df.loc[weather_df["district"] == d, "temperature_c"].to_numpy()
        for d in districts
    }

    total_weight = sum(STATION_VOLUME_WEIGHT[r.station_type] for r in stations.itertuples())
    calibration = 1.0  # targets sum to anchor by construction

    chunks: list[pd.DataFrame] = []
    delivery_rows: list[dict] = []

    for station in stations.itertuples():
        capacity = TANK_CAPACITY[station.station_type]
        st_factor = getattr(station, "station_demand_factor", 1.0)
        st_target = ANNUAL_VOLUME_LITRES_ANCHOR * calibration * (
            STATION_VOLUME_WEIGHT[station.station_type] / total_weight
        )
        del_min, del_max = DELIVERY_INTERVAL_BY_TYPE[station.station_type]
        rainfall = rain_by_district[station.district]
        temperature = temp_by_district[station.district]

        for fuel_type in station.fuel_types.split(","):
            profile = DIESEL_PROFILE if fuel_type in DIESEL_FUEL_TYPES else PETROL_PROFILE
            hourly_base = st_target * FUEL_TYPE_SHARE[fuel_type] * st_factor / n_hours
            demand, stock, delivery, stock_pct = simulate_station_fuel(
                n_hours, capacity, hourly_base, profile, cal, rainfall, rng, del_min, del_max,
            )

            labels = {f"run_out_{h}h": label_series(stock, h) for h in LSTM_HORIZONS_HOURS}

            chunk = pd.DataFrame({
                "station_id": station.station_id,
                "district": station.district,
                "station_type": station.station_type,
                "station_demand_factor": st_factor,
                "timestamp": timestamps,
                "fuel_type": fuel_type,
                "demand_litres": np.round(demand, 4),
                "stock_litres": np.round(stock, 4),
                "stock_percentage": np.round(stock_pct, 4),
                "delivery_litres": np.round(delivery, 4),
                "hour_of_day": cal["hours"],
                "day_of_week": cal["day_of_week"],
                "is_weekday": cal["is_weekday"],
                "is_poya_day": cal["is_poya"],
                "is_school_holiday": cal["is_school"],
                "is_price_change_day": cal["is_price_chg"],
                "is_pre_price_change_day": cal["is_pre_price"],
                "rainfall_mm": np.round(rainfall, 4),
                "temperature_c": np.round(temperature, 2),
                **labels,
            })
            chunks.append(chunk)

            for t in np.where(delivery > 0)[0]:
                delivery_rows.append({
                    "station_id": station.station_id,
                    "timestamp": timestamps[t],
                    "fuel_type": fuel_type,
                    "delivery_litres": round(float(delivery[t]), 4),
                    "was_delayed": False,
                })

    master = pd.concat(chunks, ignore_index=True)
    transactions = master[["station_id", "timestamp", "fuel_type", "demand_litres"]].rename(
        columns={"demand_litres": "litres_dispensed"}
    )
    stock_levels = master[["station_id", "timestamp", "fuel_type", "stock_litres", "stock_percentage"]]
    deliveries = pd.DataFrame(delivery_rows) if delivery_rows else pd.DataFrame(
        columns=["station_id", "timestamp", "fuel_type", "delivery_litres", "was_delayed"]
    )
    return master, weather_df, transactions, stock_levels, deliveries


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic dataset v2")
    parser.add_argument("--seed", type=int, default=RANDOM_SEED)
    args = parser.parse_args()

    DATA_PROCESSED.mkdir(parents=True, exist_ok=True)
    print("Generating dataset (v2)...")
    master, weather, transactions, stock_levels, deliveries = generate_dataset(seed=args.seed)

    for name, df in {
        "synthetic_station_hours.csv": master,
        "weather.csv": weather,
        "fuel_transactions.csv": transactions,
        "stock_levels.csv": stock_levels,
        "deliveries.csv": deliveries,
    }.items():
        p = DATA_PROCESSED / name
        df.to_csv(p, index=False)
        print(f"  {name}: {len(df):,} rows")

    annual = master["demand_litres"].sum()
    dev = abs(annual - ANNUAL_VOLUME_LITRES_ANCHOR) / ANNUAL_VOLUME_LITRES_ANCHOR * 100
    print(f"\nAnnual demand: {annual:,.0f} L (deviation {dev:.2f}%)")
    for h in LSTM_HORIZONS_HOURS:
        col = f"run_out_{h}h"
        print(f"  {col}: {master[col].mean()*100:.2f}% positive")
    print(f"  Low stock hours: {(master['stock_percentage'] < STOCKOUT_THRESHOLD_PCT).mean()*100:.2f}%")


if __name__ == "__main__":
    main()
