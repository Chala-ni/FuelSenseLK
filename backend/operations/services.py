"""Shared dispense validation logic."""

from decimal import Decimal
from uuid import UUID

from rest_framework import serializers

from accounts.models import User
from core.crisis import check_dispense_quota, get_active_crisis
from vehicles.models import Vehicle


def parse_qr_payload(raw: str) -> UUID:
    """Accept raw UUID or fuelsense:vehicle:{uuid} QR payload."""
    text = raw.strip()
    if text.startswith("fuelsense:vehicle:"):
        text = text.split(":")[-1]
    return UUID(text)


def validate_dispense_request(user: User, qr_id: UUID, fuel_type: str, litres: Decimal) -> dict:
    if user.role not in (User.Role.ATTENDANT, User.Role.STATION_MANAGER, User.Role.ADMIN, User.Role.SUPER_ADMIN):
        raise serializers.ValidationError("Only station staff can dispense fuel.")
    if user.role == User.Role.ATTENDANT and not user.station_id:
        raise serializers.ValidationError("Attendant is not assigned to a station.")

    try:
        vehicle = Vehicle.objects.select_related("owner").get(qr_id=qr_id, is_active=True)
    except Vehicle.DoesNotExist as exc:
        raise serializers.ValidationError({"qr_id": "Vehicle not found or inactive."}) from exc

    station = user.station
    if not station:
        raise serializers.ValidationError("No station assigned.")

    if fuel_type not in station.fuel_types:
        raise serializers.ValidationError({"fuel_type": "Fuel type not sold at this station."})

    allowed, quota_info = check_dispense_quota(vehicle, fuel_type, litres)
    crisis_active = get_active_crisis() is not None

    result = {
        "valid": allowed,
        "vehicle": {
            "id": vehicle.id,
            "plate_number": vehicle.plate_number,
            "vehicle_type": vehicle.vehicle_type,
            "qr_id": str(vehicle.qr_id),
        },
        "station": {"id": station.id, "name": station.name},
        "fuel_type": fuel_type,
        "litres": float(litres),
        "crisis_mode_active": crisis_active,
        "quota": quota_info,
    }
    if not allowed:
        result["blocked_reason"] = "crisis_quota_exceeded"
    return result
