"""Station query helpers (SQLite-compatible JSON filtering)."""

from django.conf import settings

from stations.models import Station


def filter_by_fuel_type(qs, fuel_type: str | None):
    if not fuel_type:
        return qs
    if settings.DATABASES["default"]["ENGINE"].endswith("postgresql") or "postgis" in settings.DATABASES["default"]["ENGINE"]:
        return qs.filter(fuel_types__contains=[fuel_type])
    ids = [s.id for s in qs if fuel_type in (s.fuel_types or [])]
    return qs.filter(id__in=ids)
