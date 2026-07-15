"""Seed stations from ml/data/raw/stations.csv"""

import csv
from pathlib import Path

from django.core.management.base import BaseCommand

from stations.models import Station


class Command(BaseCommand):
    help = "Load station seed data from ML pipeline CSV"

    def handle(self, *args, **options):
        from django.conf import settings
        csv_path = settings.BASE_DIR.parent / "ml" / "data" / "raw" / "stations.csv"
        if not csv_path.exists():
            self.stderr.write(f"Missing {csv_path}. Run ml/scripts/generate_stations.py first.")
            return

        created = 0
        with csv_path.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                _, was_created = Station.objects.update_or_create(
                    name=row["name"],
                    defaults={
                        "ml_station_id": int(row["station_id"]),
                        "district": row["district"],
                        "station_type": row["station_type"],
                        "latitude": float(row["latitude"]),
                        "longitude": float(row["longitude"]),
                        "tank_capacity_litres": int(row["tank_capacity_litres"]),
                        "fuel_types": row["fuel_types"].split(","),
                        "is_active": row.get("is_active", "True") in ("True", "true", "1"),
                    },
                )
                if was_created:
                    created += 1

        self.stdout.write(self.style.SUCCESS(f"Stations seeded: {created} created, {Station.objects.count()} total"))
