from django.conf import settings
from django.db import models

from core.constants import CROWD_STATUSES, FUEL_TYPES


class CrowdReport(models.Model):
    station = models.ForeignKey("stations.Station", on_delete=models.CASCADE, related_name="crowd_reports")
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="crowd_reports",
    )
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    status = models.CharField(max_length=20, choices=CROWD_STATUSES)
    queue_length = models.PositiveSmallIntegerField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")
    reported_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    is_verified = models.BooleanField(default=False)

    class Meta:
        ordering = ["-reported_at"]

    def __str__(self) -> str:
        return f"{self.station.name} — {self.status}"
