from django.contrib import admin

from .models import DeliveryLog, DispenseLog


@admin.register(DispenseLog)
class DispenseLogAdmin(admin.ModelAdmin):
    list_display = ("station", "fuel_type", "litres", "dispensed_at")
    list_filter = ("fuel_type", "station")


@admin.register(DeliveryLog)
class DeliveryLogAdmin(admin.ModelAdmin):
    list_display = ("station", "fuel_type", "litres", "delivered_at")
    list_filter = ("fuel_type", "station")
