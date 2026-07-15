"""Celery tasks for ML forecasting."""

import logging

from celery import shared_task

from forecasting.ml_inference import models_available

logger = logging.getLogger(__name__)


@shared_task(name="forecasting.run_prophet_forecasts")
def run_prophet_forecasts():
    from .services import refresh_prophet_forecasts

    available = models_available()
    created = refresh_prophet_forecasts()
    model = "prophet_hourly_v1" if available["prophet"] else "heuristic_v1"
    logger.info("Forecasts created: %s (model=%s)", created, model)
    return {"status": "ok", "forecasts_created": created, "model": model, "ml_available": available["prophet"]}


@shared_task(name="forecasting.run_depletion_risk")
def run_depletion_risk():
    from .services import refresh_depletion_risk

    available = models_available()
    created = refresh_depletion_risk()
    model = "lstm_v1" if available["lstm"] else "heuristic_v1"
    logger.info("Depletion risks created: %s (model=%s)", created, model)
    return {"status": "ok", "risks_created": created, "model": model, "ml_available": available["lstm"]}
