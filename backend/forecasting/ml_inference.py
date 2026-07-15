"""Load trained Prophet/LSTM models from ml/models/ and run inference."""

from __future__ import annotations

import logging
import pickle
import re
from datetime import timedelta
from decimal import Decimal
from functools import lru_cache
from pathlib import Path

import numpy as np
from django.conf import settings
from django.db.models import Sum
from django.utils import timezone

logger = logging.getLogger(__name__)

LSTM_LOOKBACK = 12
LSTM_HORIZONS = (6, 12, 24)
LSTM_FEATURES = (
    "stock_percentage",
    "hour_of_day",
    "rainfall_mm",
    "is_poya_day",
    "is_weekday",
    "demand_litres",
)
PROPHET_REGRESSORS = ("is_poya_day", "is_school_holiday", "rainfall_mm", "is_price_change_day")
PROPHET_HORIZONS = (24, 48, 72)


def ml_models_root() -> Path:
    return Path(getattr(settings, "ML_MODELS_ROOT", settings.BASE_DIR.parent / "ml" / "models"))


def models_available() -> dict[str, bool]:
    root = ml_models_root()
    lstm_dir = root / "lstm"
    prophet_dir = root / "prophet" / getattr(settings, "ML_PROPHET_GRANULARITY", "hourly")
    return {
        "lstm": (lstm_dir / "depletion_risk_6h.keras").exists(),
        "prophet": prophet_dir.exists() and any(prophet_dir.glob("station_*_petrol_92.pkl")),
    }


def resolve_ml_station_id(station) -> int | None:
    if station.ml_station_id:
        return station.ml_station_id
    match = re.match(r"FuelSense Station (\d+)", station.name)
    if match:
        return int(match.group(1))
    return station.pk


@lru_cache(maxsize=3)
def _load_lstm(horizon: int):
    from tensorflow import keras

    lstm_dir = ml_models_root() / "lstm"
    model_path = lstm_dir / f"depletion_risk_{horizon}h_best.keras"
    if not model_path.exists():
        model_path = lstm_dir / f"depletion_risk_{horizon}h.keras"
    scaler_path = lstm_dir / f"scaler_{horizon}h.pkl"
    with scaler_path.open("rb") as f:
        scaler = pickle.load(f)
    return keras.models.load_model(model_path), scaler


@lru_cache(maxsize=256)
def _load_prophet(ml_station_id: int, fuel_type: str):
    path = (
        ml_models_root()
        / "prophet"
        / getattr(settings, "ML_PROPHET_GRANULARITY", "hourly")
        / f"station_{ml_station_id}_{fuel_type}.pkl"
    )
    if not path.exists():
        return None
    with path.open("rb") as f:
        return pickle.load(f)


def _hourly_demand_litres(station, fuel_type: str) -> float:
    from operations.models import DispenseLog

    since = timezone.now() - timedelta(hours=24)
    total = (
        DispenseLog.objects.filter(station=station, fuel_type=fuel_type, dispensed_at__gte=since).aggregate(
            t=Sum("litres")
        )["t"]
        or 0
    )
    if total:
        return float(total) / 24.0
    return max(float(station.tank_capacity_litres) * 0.02, 50.0)


def build_lstm_window(stock_pct: float, demand_litres: float, at=None) -> np.ndarray:
    """Build (1, lookback, features) causal window from current station state."""
    at = at or timezone.now()
    rows = []
    for offset in range(LSTM_LOOKBACK, 0, -1):
        ts = at - timedelta(hours=offset)
        rows.append(
            [
                stock_pct / 100.0,
                ts.hour / 23.0,
                0.0,
                0.0,
                1.0 if ts.weekday() < 5 else 0.0,
                demand_litres,
            ]
        )
    return np.array([rows], dtype=np.float32)


def predict_lstm_risk(stock_pct: float, demand_litres: float, horizon: int) -> float:
    model, scaler = _load_lstm(horizon)
    window = build_lstm_window(stock_pct, demand_litres)
    n, lb, feats = window.shape
    flat = scaler.transform(window.reshape(-1, feats))
    scaled = flat.reshape(n, lb, feats)
    return float(model.predict(scaled, verbose=0).ravel()[0])


def _naive_hourly_range(hours: int):
    import pandas as pd

    now = timezone.now().replace(minute=0, second=0, microsecond=0)
    if timezone.is_aware(now):
        now = timezone.make_naive(now, timezone.get_current_timezone())
    return pd.date_range(start=now + timedelta(hours=1), periods=hours, freq="h", tz=None)


def predict_prophet_demand(ml_station_id: int, fuel_type: str, horizon_hours: int) -> float | None:
    import pandas as pd

    model = _load_prophet(ml_station_id, fuel_type)
    if model is None:
        return None

    future = pd.DataFrame(
        {
            "ds": _naive_hourly_range(horizon_hours),
            "is_poya_day": 0.0,
            "is_school_holiday": 0.0,
            "rainfall_mm": 0.0,
            "is_price_change_day": 0.0,
        }
    )
    forecast = model.predict(future)
    return float(max(forecast["yhat"].sum(), 0.0))


def prophet_components(ml_station_id: int, fuel_type: str, hours: int = 72) -> dict | None:
    import pandas as pd

    model = _load_prophet(ml_station_id, fuel_type)
    if model is None:
        return None

    future = pd.DataFrame(
        {
            "ds": _naive_hourly_range(hours),
            "is_poya_day": 0.0,
            "is_school_holiday": 0.0,
            "rainfall_mm": 0.0,
            "is_price_change_day": 0.0,
        }
    )
    forecast = model.predict(future)
    return {
        "model": f"prophet_{getattr(settings, 'ML_PROPHET_GRANULARITY', 'hourly')}",
        "trend": [round(float(v), 2) for v in forecast["trend"].tolist()],
        "weekly": [round(float(v), 4) for v in forecast.get("weekly", pd.Series([0] * hours)).tolist()],
        "daily": [round(float(v), 4) for v in forecast.get("daily", pd.Series([0] * hours)).tolist()],
        "yhat": [round(float(v), 2) for v in forecast["yhat"].tolist()],
    }


def risk_tier(score: float) -> str:
    if score < 0.2:
        return "green"
    if score < 0.6:
        return "amber"
    return "red"


def estimate_hours_to_empty(stock_pct: float, demand_litres: float) -> Decimal:
    if stock_pct <= 0 or demand_litres <= 0:
        return Decimal("0")
    # Rough heuristic from stock % and recent demand
    return Decimal(str(round((stock_pct / 100.0) * 500 / max(demand_litres, 1.0), 1)))
