from django.contrib import admin

from .models import Station, StockLevel


class StockLevelInline(admin.TabularInline):
    model = StockLevel
    extra = 0


@admin.register(Station)
class StationAdmin(admin.ModelAdmin):
    list_display = ("name", "district", "station_type", "is_active")
    list_filter = ("district", "station_type", "is_active")
    search_fields = ("name", "district")
    inlines = [StockLevelInline]
