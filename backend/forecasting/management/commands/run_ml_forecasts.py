from django.core.management.base import BaseCommand

from forecasting.ml_inference import models_available
from forecasting.services import refresh_depletion_risk, refresh_prophet_forecasts


class Command(BaseCommand):
    help = "Run Prophet + LSTM inference and store forecasts/risks in the database"

    def handle(self, *args, **options):
        available = models_available()
        self.stdout.write(f"ML models available: {available}")
        forecasts = refresh_prophet_forecasts()
        risks = refresh_depletion_risk()
        self.stdout.write(self.style.SUCCESS(f"Forecasts: {forecasts}, Depletion risks: {risks}"))
