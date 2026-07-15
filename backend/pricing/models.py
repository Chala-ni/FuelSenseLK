from django.db import models

from core.constants import FUEL_TYPES


class PriceHistory(models.Model):
    fuel_type = models.CharField(max_length=20, choices=FUEL_TYPES)
    price_per_litre = models.DecimalField(max_digits=8, decimal_places=2)
    effective_from = models.DateField()
    source = models.CharField(max_length=100, default="CPC")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-effective_from", "fuel_type"]
        verbose_name_plural = "price history"

    def __str__(self) -> str:
        return f"{self.fuel_type} — Rs {self.price_per_litre} from {self.effective_from}"
