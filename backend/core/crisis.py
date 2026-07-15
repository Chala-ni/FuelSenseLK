"""Crisis mode quota enforcement for dispense flow."""

from datetime import timedelta
from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone

from crisis.models import CrisisMode, CrisisQuota
from operations.models import DispenseLog


def get_active_crisis() -> CrisisMode | None:
    return CrisisMode.objects.filter(is_active=True).order_by("-activated_at").first()


def check_dispense_quota(vehicle, fuel_type: str, litres: Decimal) -> tuple[bool, dict]:
    """
    Return (allowed, info).
    info includes remaining_litres when crisis mode applies.
    """
    crisis = get_active_crisis()
    if not crisis:
        return True, {}

    quota = CrisisQuota.objects.filter(
        crisis=crisis,
        vehicle_type=vehicle.vehicle_type,
        fuel_type=fuel_type,
    ).first()
    if not quota:
        return True, {}

    since = timezone.now() - timedelta(hours=quota.cooldown_hours)
    used = (
        DispenseLog.objects.filter(
            vehicle=vehicle,
            fuel_type=fuel_type,
            dispensed_at__gte=since,
        ).aggregate(total=Sum("litres"))["total"]
        or Decimal("0")
    )
    remaining = quota.max_litres - used
    info = {
        "max_litres": float(quota.max_litres),
        "used_litres": float(used),
        "remaining_litres": float(max(Decimal("0"), remaining)),
        "cooldown_hours": quota.cooldown_hours,
    }
    if litres > remaining:
        return False, info
    info["remaining_after"] = float(remaining - litres)
    return True, info
