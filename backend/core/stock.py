"""Stock level helpers for dispense/delivery flows (Sprint 3 will call these)."""

from decimal import Decimal

from stations.models import Station, StockLevel


def ensure_stock_rows(station: Station) -> None:
    for fuel_type in station.fuel_types:
        StockLevel.objects.get_or_create(
            station=station,
            fuel_type=fuel_type,
            defaults={"current_litres": Decimal("0"), "percentage": Decimal("0")},
        )


def apply_stock_delta(station: Station, fuel_type: str, litres_delta: Decimal) -> StockLevel:
    ensure_stock_rows(station)
    row = StockLevel.objects.select_for_update().get(station=station, fuel_type=fuel_type)
    capacity = Decimal(station.tank_capacities.get(fuel_type, station.tank_capacity_litres))
    new_litres = max(Decimal("0"), row.current_litres + litres_delta)
    row.current_litres = new_litres
    row.percentage = (new_litres / capacity * 100) if capacity else Decimal("0")
    row.save(update_fields=["current_litres", "percentage", "last_updated"])
    return row
