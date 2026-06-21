from django.db import models


class Station(models.Model):
    class StationType(models.TextChoices):
        HIGHWAY = "highway", "Highway"
        URBAN = "urban", "Urban"
        SUBURBAN = "suburban", "Suburban"
        RURAL = "rural", "Rural"

    name = models.CharField(max_length=200)
    district = models.CharField(max_length=100)
    station_type = models.CharField(max_length=20, choices=StationType.choices)
    latitude = models.FloatField()
    longitude = models.FloatField()
    tank_capacity_litres = models.PositiveIntegerField(default=20000)
    fuel_types = models.JSONField(default=list)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name
