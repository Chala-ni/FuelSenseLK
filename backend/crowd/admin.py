from django.contrib import admin

from .models import CrowdReport


@admin.register(CrowdReport)
class CrowdReportAdmin(admin.ModelAdmin):
    list_display = ("station", "fuel_type", "status", "reported_at", "is_verified")
    list_filter = ("status", "is_verified")
