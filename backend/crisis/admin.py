from django.contrib import admin

from .models import CrisisMode, CrisisQuota


class CrisisQuotaInline(admin.TabularInline):
    model = CrisisQuota
    extra = 0


@admin.register(CrisisMode)
class CrisisModeAdmin(admin.ModelAdmin):
    list_display = ("is_active", "activated_at", "deactivated_at")
    inlines = [CrisisQuotaInline]
