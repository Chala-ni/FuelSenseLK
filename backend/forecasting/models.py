from django.db import models

from core.constants import FUEL_TYPES, RISK_TIERS


class Forecast(models.Model):
    station = models.ForeignKey("stations.Station", on_delete=models.CASCADE, related_name="forecasts")
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    horizon_hours = models.PositiveSmallIntegerField()
    predicted_demand_litres = models.DecimalField(max_digits=12, decimal_places=2)
    model_name = models.CharField(max_length=50, default="prophet")
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-generated_at"]
        indexes = [
            models.Index(fields=["station", "fuel_type", "-generated_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.station.name} {self.horizon_hours}h forecast"


class DepletionRisk(models.Model):
    station = models.ForeignKey("stations.Station", on_delete=models.CASCADE, related_name="depletion_risks")
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    horizon_hours = models.PositiveSmallIntegerField()
    risk_score = models.DecimalField(max_digits=5, decimal_places=4)
    risk_tier = models.CharField(max_length=10, choices=RISK_TIERS)
    estimated_hours_to_empty = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    model_name = models.CharField(max_length=50, default="lstm")
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-generated_at"]
        indexes = [
            models.Index(fields=["station", "fuel_type", "-generated_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.station.name} {self.risk_tier} ({self.horizon_hours}h)"
