from django.contrib import admin

from .models import DepletionRisk, Forecast


@admin.register(Forecast)
class ForecastAdmin(admin.ModelAdmin):
    list_display = ("station", "fuel_type", "horizon_hours", "predicted_demand_litres", "generated_at")


@admin.register(DepletionRisk)
class DepletionRiskAdmin(admin.ModelAdmin):
    list_display = ("station", "fuel_type", "risk_tier", "risk_score", "generated_at")
    list_filter = ("risk_tier",)
