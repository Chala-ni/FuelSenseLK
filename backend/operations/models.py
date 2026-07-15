from django.conf import settings
from django.db import models

from core.constants import FUEL_TYPES


class DispenseLog(models.Model):
    station = models.ForeignKey("stations.Station", on_delete=models.CASCADE, related_name="dispense_logs")
    attendant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="dispense_logs",
    )
    vehicle = models.ForeignKey(
        "vehicles.Vehicle",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="dispense_logs",
    )
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    litres = models.DecimalField(max_digits=10, decimal_places=2)
    price_per_litre = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    dispensed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-dispensed_at"]

    def __str__(self) -> str:
        return f"{self.station.name} — {self.litres}L {self.fuel_type}"


class DeliveryLog(models.Model):
    station = models.ForeignKey("stations.Station", on_delete=models.CASCADE, related_name="delivery_logs")
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    litres = models.DecimalField(max_digits=12, decimal_places=2)
    delivered_at = models.DateTimeField()
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="delivery_logs",
    )
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-delivered_at"]

    def __str__(self) -> str:
        return f"{self.station.name} — +{self.litres}L {self.fuel_type}"
