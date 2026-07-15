from django.conf import settings
from django.db import models

from core.constants import FUEL_TYPES, VEHICLE_TYPES


class CrisisMode(models.Model):
    is_active = models.BooleanField(default=False)
    activated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="crisis_activations",
    )
    message = models.TextField(blank=True, default="")
    activated_at = models.DateTimeField(auto_now_add=True)
    deactivated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-activated_at"]

    def __str__(self) -> str:
        state = "active" if self.is_active else "inactive"
        return f"Crisis mode ({state})"


class CrisisQuota(models.Model):
    crisis = models.ForeignKey(CrisisMode, on_delete=models.CASCADE, related_name="quotas")
    vehicle_type = models.CharField(max_length=20, choices=VEHICLE_TYPES)
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    max_litres = models.DecimalField(max_digits=8, decimal_places=2)
    cooldown_hours = models.PositiveSmallIntegerField(default=24)

    class Meta:
        unique_together = ("crisis", "vehicle_type", "fuel_type")

    def __str__(self) -> str:
        return f"{self.vehicle_type} — {self.max_litres}L {self.fuel_type}"
