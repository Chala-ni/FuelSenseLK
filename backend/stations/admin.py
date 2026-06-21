from django.contrib import admin

from .models import Station


@admin.register(Station)
class StationAdmin(admin.ModelAdmin):
    list_display = ("name", "district", "station_type", "is_active")
    list_filter = ("district", "station_type", "is_active")
