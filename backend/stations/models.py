from django.db import models

from core.constants import FUEL_TYPES


class Station(models.Model):
    class StationType(models.TextChoices):
        HIGHWAY = "highway", "Highway"
        URBAN = "urban", "Urban"
        SUBURBAN = "suburban", "Suburban"
        RURAL = "rural", "Rural"

    name = models.CharField(max_length=200)
    ml_station_id = models.PositiveIntegerField(null=True, blank=True, unique=True)
    address = models.CharField(max_length=300, blank=True, default="")
    district = models.CharField(max_length=100)
    station_type = models.CharField(max_length=20, choices=StationType.choices)
    latitude = models.FloatField()
    longitude = models.FloatField()
    tank_capacity_litres = models.PositiveIntegerField(default=20000)
    tank_capacities = models.JSONField(default=dict, blank=True)
    fuel_types = models.JSONField(default=list)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name


class StockLevel(models.Model):
    station = models.ForeignKey(Station, on_delete=models.CASCADE, related_name="stock_levels")
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    current_litres = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    percentage = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    last_updated = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("station", "fuel_type")
        ordering = ["station", "fuel_type"]

    def __str__(self) -> str:
        return f"{self.station.name} — {self.fuel_type}: {self.percentage}%"
