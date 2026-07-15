"""Forecast and depletion risk — ML models with heuristic fallback."""

import logging
from decimal import Decimal

from forecasting.ml_inference import (
    LSTM_HORIZONS,
    PROPHET_HORIZONS,
    _hourly_demand_litres,
    estimate_hours_to_empty,
    models_available,
    predict_lstm_risk,
    predict_prophet_demand,
    prophet_components,
    resolve_ml_station_id,
    risk_tier,
)
from forecasting.models import DepletionRisk, Forecast
from stations.models import StockLevel

logger = logging.getLogger(__name__)


def refresh_depletion_risk() -> int:
    """LSTM depletion risk when models exist; otherwise heuristic."""
    use_ml = models_available()["lstm"]
    count = 0

    for stock in StockLevel.objects.select_related("station"):
        pct = float(stock.percentage)
        demand = _hourly_demand_litres(stock.station, stock.fuel_type) if use_ml else 0.0

        for horizon in LSTM_HORIZONS:
            model_name = "heuristic_v1"
            score = _heuristic_score(pct, horizon)
            if use_ml:
                try:
                    score = predict_lstm_risk(pct, demand, horizon)
                    model_name = "lstm_v1"
                except Exception as exc:
                    logger.warning("LSTM inference failed for station %s: %s", stock.station_id, exc)

            DepletionRisk.objects.create(
                station=stock.station,
                fuel_type=stock.fuel_type,
                horizon_hours=horizon,
                risk_score=Decimal(str(round(score, 4))),
                risk_tier=risk_tier(score),
                estimated_hours_to_empty=estimate_hours_to_empty(pct, demand or 1.0),
                model_name=model_name,
            )
            count += 1
    return count


def _heuristic_score(pct: float, horizon: int) -> float:
    if pct <= 0:
        return 0.95
    if pct < 10:
        return 0.85 if horizon <= 12 else 0.7
    if pct < 20:
        return 0.55 if horizon <= 12 else 0.35
    if pct < 50:
        return 0.25
    return 0.08


def refresh_prophet_forecasts() -> int:
    """Prophet demand forecasts when models exist; otherwise heuristic."""
    use_ml = models_available()["prophet"]
    count = 0

    for stock in StockLevel.objects.select_related("station"):
        ml_id = resolve_ml_station_id(stock.station)
        for horizon in PROPHET_HORIZONS:
            model_name = "heuristic_v1"
            predicted = float(stock.current_litres) * 0.02 + 50
            predicted = predicted * (horizon / 24)

            if use_ml and ml_id:
                try:
                    ml_value = predict_prophet_demand(ml_id, stock.fuel_type, horizon)
                    if ml_value is not None:
                        predicted = ml_value
                        model_name = "prophet_hourly_v1"
                except Exception as exc:
                    logger.warning("Prophet inference failed for station %s: %s", ml_id, exc)

            Forecast.objects.create(
                station=stock.station,
                fuel_type=stock.fuel_type,
                horizon_hours=horizon,
                predicted_demand_litres=Decimal(str(round(predicted, 2))),
                model_name=model_name,
            )
            count += 1
    return count


def forecast_components(station_id: int, fuel_type: str) -> dict:
    """Prophet component breakdown for charts."""
    from stations.models import Station

    station = Station.objects.filter(pk=station_id).first()
    ml_id = resolve_ml_station_id(station) if station else None

    if ml_id and models_available()["prophet"]:
        components = prophet_components(ml_id, fuel_type)
        if components:
            components["station_id"] = station_id
            components["fuel_type"] = fuel_type
            return components

    forecasts = Forecast.objects.filter(station_id=station_id, fuel_type=fuel_type).order_by("-generated_at")[:72]
    return {
        "station_id": station_id,
        "fuel_type": fuel_type,
        "model": "heuristic_v1",
        "trend": [float(f.predicted_demand_litres) for f in forecasts],
        "weekly": [1.0, 1.1, 1.05, 0.95, 1.0, 0.85, 0.9],
        "daily": [0.6, 0.5, 0.5, 0.55, 0.7, 0.9, 1.0, 0.95, 0.85, 0.75, 0.7, 0.65],
        "note": "Heuristic fallback — Prophet model not found for this station",
    }
