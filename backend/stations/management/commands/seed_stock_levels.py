"""Seed latest stock levels from ML pipeline CSV."""

import csv
from decimal import Decimal
from pathlib import Path

from django.core.management.base import BaseCommand
from django.db import transaction

from stations.models import Station, StockLevel


class Command(BaseCommand):
    help = "Load latest stock snapshot from ml/data/processed/stock_levels.csv"

    def add_arguments(self, parser):
        parser.add_argument(
            "--at",
            default="",
            help="Optional ISO timestamp upper bound (e.g. 2025-06-01 00:00:00)",
        )

    def handle(self, *args, **options):
        from django.conf import settings

        stock_path = settings.BASE_DIR.parent / "ml" / "data" / "processed" / "stock_levels.csv"
        stations_path = settings.BASE_DIR.parent / "ml" / "data" / "raw" / "stations.csv"
        if not stock_path.exists():
            self.stderr.write(f"Missing {stock_path}")
            return

        id_to_name = {}
        with stations_path.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                id_to_name[int(row["station_id"])] = row["name"]

        name_to_station = {s.name: s for s in Station.objects.all()}
        upper_bound = options["at"] or None
        latest: dict[tuple[int, str], dict] = {}

        with stock_path.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                ts = row["timestamp"]
                if upper_bound and ts > upper_bound:
                    continue
                key = (int(row["station_id"]), row["fuel_type"])
                if key not in latest or ts > latest[key]["timestamp"]:
                    latest[key] = row

        created = updated = skipped = 0
        with transaction.atomic():
            for (station_id, fuel_type), row in latest.items():
                name = id_to_name.get(station_id)
                station = name_to_station.get(name) if name else None
                if not station:
                    skipped += 1
                    continue
                if fuel_type not in station.fuel_types:
                    continue
                _, was_created = StockLevel.objects.update_or_create(
                    station=station,
                    fuel_type=fuel_type,
                    defaults={
                        "current_litres": Decimal(row["stock_litres"]).quantize(Decimal("0.01")),
                        "percentage": Decimal(row["stock_percentage"]).quantize(Decimal("0.01")),
                    },
                )
                if was_created:
                    created += 1
                else:
                    updated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Stock levels: {created} created, {updated} updated, {skipped} skipped"
            )
        )
