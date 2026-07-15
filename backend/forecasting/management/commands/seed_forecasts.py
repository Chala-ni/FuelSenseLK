from django.core.management.base import BaseCommand

from forecasting.services import refresh_depletion_risk, refresh_prophet_forecasts


class Command(BaseCommand):
    help = "Seed forecast/depletion data using trained ML models (heuristic fallback if missing)"

    def handle(self, *args, **options):
        f = refresh_prophet_forecasts()
        d = refresh_depletion_risk()
        self.stdout.write(self.style.SUCCESS(f"Forecasts: {f}, Depletion risks: {d}"))
