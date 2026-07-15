from django.contrib import admin

from .models import PriceHistory


@admin.register(PriceHistory)
class PriceHistoryAdmin(admin.ModelAdmin):
    list_display = ("fuel_type", "price_per_litre", "effective_from", "source")
    list_filter = ("fuel_type",)
