import math

from rest_framework.permissions import BasePermission


class RolePermission(BasePermission):
    """Allow only users whose role is in `allowed_roles`."""

    allowed_roles: tuple[str, ...] = ()

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.role in self.allowed_roles
        )


class IsDriver(RolePermission):
    allowed_roles = ("driver",)


class IsAttendant(RolePermission):
    allowed_roles = ("attendant",)


class IsStationManager(RolePermission):
    allowed_roles = ("station_manager",)


class IsAdmin(RolePermission):
    allowed_roles = ("admin", "super_admin")


class IsSuperAdmin(RolePermission):
    allowed_roles = ("super_admin",)


class IsAdminOrManager(RolePermission):
    allowed_roles = ("admin", "super_admin", "station_manager")


class IsAttendantOrManager(RolePermission):
    allowed_roles = ("attendant", "station_manager", "admin", "super_admin")


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in km (SQLite-compatible nearest-station query)."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
