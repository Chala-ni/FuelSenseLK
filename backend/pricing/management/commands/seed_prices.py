"""Seed CPC reference fuel prices."""

from datetime import date
from decimal import Decimal

from django.core.management.base import BaseCommand

from pricing.models import PriceHistory


class Command(BaseCommand):
    help = "Seed reference fuel prices (CPC, effective 2025-01-01)"

    PRICES = {
        "petrol_92": Decimal("363.00"),
        "petrol_95": Decimal("398.00"),
        "auto_diesel": Decimal("318.00"),
        "super_diesel": Decimal("348.00"),
    }

    def handle(self, *args, **options):
        effective = date(2025, 1, 1)
        created = 0
        for fuel_type, price in self.PRICES.items():
            _, was_created = PriceHistory.objects.get_or_create(
                fuel_type=fuel_type,
                effective_from=effective,
                defaults={"price_per_litre": price, "source": "CPC reference"},
            )
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f"Prices seeded: {created} new, {PriceHistory.objects.count()} total"))
