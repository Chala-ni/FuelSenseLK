"""Seed sample dispense, delivery, and crowd data for demo dashboards."""

import random
from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from core.constants import FUEL_TYPES
from crowd.models import CrowdReport
from operations.models import DeliveryLog, DispenseLog
from pricing.models import PriceHistory
from stations.models import Station
from vehicles.models import Vehicle


class Command(BaseCommand):
    help = "Create demo dispense/delivery/crowd records for dashboards"

    def handle(self, *args, **options):
        attendant = User.objects.filter(email="attendant@demo.fuelsense.lk").first()
        driver = User.objects.filter(email="driver@demo.fuelsense.lk").first()
        manager_station = (
            User.objects.filter(email="manager@demo.fuelsense.lk").select_related("station").first()
        )
        station = manager_station.station if manager_station and manager_station.station else Station.objects.first()

        if not station:
            self.stderr.write("No stations found. Run seed_stations first.")
            return

        vehicle = None
        if driver:
            vehicle, _ = Vehicle.objects.get_or_create(
                owner=driver,
                plate_number="CAB-1234",
                defaults={"vehicle_type": "car"},
            )

        prices = {}
        for ft, _ in FUEL_TYPES:
            row = PriceHistory.objects.filter(fuel_type=ft).order_by("-effective_from").first()
            if row:
                prices[ft] = row.price_per_litre
        if not prices:
            prices = {
                "petrol_92": Decimal("363.00"),
                "auto_diesel": Decimal("318.00"),
            }

        now = timezone.now()
        dispense_created = 0
        if attendant and not DispenseLog.objects.filter(station=station, dispensed_at__date=now.date()).exists():
            for i in range(12):
                fuel = random.choice(station.fuel_types)
                DispenseLog.objects.create(
                    station=station,
                    attendant=attendant,
                    vehicle=vehicle,
                    fuel_type=fuel,
                    litres=Decimal(str(round(random.uniform(5, 45), 2))),
                    price_per_litre=prices.get(fuel, Decimal("363.00")),
                    dispensed_at=now - timedelta(hours=random.randint(0, 10), minutes=random.randint(0, 59)),
                )
                dispense_created += 1

        delivery_created = 0
        if DeliveryLog.objects.count() < 5:
            for i, st in enumerate(Station.objects.order_by("id")[:8]):
                fuel = st.fuel_types[0]
                DeliveryLog.objects.create(
                    station=st,
                    fuel_type=fuel,
                    litres=Decimal(str(random.randint(2000, 8000))),
                    delivered_at=now - timedelta(days=i % 5, hours=random.randint(1, 12)),
                    recorded_by=manager_station,
                    notes="Demo delivery seed",
                )
                delivery_created += 1

        crowd_created = 0
        if not CrowdReport.objects.exists():
            for st in Station.objects.order_by("id")[:6]:
                CrowdReport.objects.create(
                    station=st,
                    fuel_type=st.fuel_types[0],
                    status=random.choice(["in_stock", "low", "out_of_stock"]),
                    reported_at=now - timedelta(minutes=random.randint(10, 90)),
                )
                crowd_created += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Demo ops: {dispense_created} dispenses, {delivery_created} deliveries, {crowd_created} crowd reports"
            )
        )
