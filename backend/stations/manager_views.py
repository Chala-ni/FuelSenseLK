from django.db.models import Count, Sum
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from forecasting.models import DepletionRisk
from operations.models import DeliveryLog, DispenseLog
from stations.models import Station
from stations.serializers import StationDetailSerializer


class ManagerDashboardView(APIView):
    permission_classes = (IsAuthenticated,)

    def get(self, request):
        user = request.user
        if user.role not in (User.Role.STATION_MANAGER, User.Role.ADMIN, User.Role.SUPER_ADMIN):
            return Response({"detail": "Manager access required."}, status=403)

        station = user.station
        if user.role == User.Role.STATION_MANAGER and not station:
            return Response({"detail": "No station assigned."}, status=400)

        if user.role in (User.Role.ADMIN, User.Role.SUPER_ADMIN):
            station_id = request.query_params.get("station_id")
            if station_id:
                station = Station.objects.filter(pk=station_id).first()
            elif not station:
                station = Station.objects.first()

        today = timezone.now().date()
        dispense_today = DispenseLog.objects.filter(station=station, dispensed_at__date=today).count()
        litres_today = (
            DispenseLog.objects.filter(station=station, dispensed_at__date=today).aggregate(t=Sum("litres"))["t"]
            or 0
        )
        attendant_activity = (
            DispenseLog.objects.filter(station=station, dispensed_at__date=today)
            .values("attendant__email")
            .annotate(count=Count("id"))
            .order_by("-count")
        )
        recent_deliveries = DeliveryLog.objects.filter(station=station).order_by("-delivered_at")[:10]
        risks = DepletionRisk.objects.filter(station=station).order_by("-generated_at")[:10]

        return Response(
            {
                "station": StationDetailSerializer(station).data,
                "dispense_today": dispense_today,
                "litres_today": float(litres_today),
                "attendant_activity": list(attendant_activity),
                "recent_deliveries": [
                    {
                        "id": d.id,
                        "fuel_type": d.fuel_type,
                        "litres": float(d.litres),
                        "delivered_at": d.delivered_at,
                    }
                    for d in recent_deliveries
                ],
                "depletion_risks": [
                    {
                        "fuel_type": r.fuel_type,
                        "horizon_hours": r.horizon_hours,
                        "risk_tier": r.risk_tier,
                        "risk_score": float(r.risk_score),
                        "estimated_hours_to_empty": float(r.estimated_hours_to_empty)
                        if r.estimated_hours_to_empty is not None
                        else None,
                    }
                    for r in risks
                ],
            }
        )
