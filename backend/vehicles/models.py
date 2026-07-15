import uuid

from django.conf import settings
from django.db import models

from core.constants import FUEL_TYPES, VEHICLE_TYPES


class Vehicle(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="vehicles",
    )
    plate_number = models.CharField(max_length=20)
    vehicle_type = models.CharField(max_length=20, choices=VEHICLE_TYPES)
    qr_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("owner", "plate_number")
        ordering = ["plate_number"]

    def __str__(self) -> str:
        return self.plate_number
