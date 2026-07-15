from datetime import timedelta

from django.db.models import Avg, Count, Sum
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from core.constants import FUEL_TYPES
from core.permissions import IsAdmin
from forecasting.models import DepletionRisk
from operations.models import DispenseLog
from stations.models import Station, StockLevel


class NetworkAnalyticsView(APIView):
    """Aggregated network metrics for the admin analytics dashboard (M13)."""

    permission_classes = (IsAuthenticated, IsAdmin)

    def get(self, request):
        today = timezone.now().date()
        week_ago = today - timedelta(days=6)

        stations = Station.objects.filter(is_active=True)
        total_stations = stations.count()

        dispense_qs = DispenseLog.objects.filter(dispensed_at__date=today)
        dispense_today = dispense_qs.count()
        litres_today = float(dispense_qs.aggregate(t=Sum("litres"))["t"] or 0)

        latest_risks = {}
        for risk in DepletionRisk.objects.select_related("station").order_by("-generated_at")[:500]:
            key = (risk.station_id, risk.fuel_type, risk.horizon_hours)
            if key not in latest_risks:
                latest_risks[key] = risk

        red_count = sum(1 for r in latest_risks.values() if r.risk_tier == "red")
        amber_count = sum(1 for r in latest_risks.values() if r.risk_tier == "amber")

        stock_agg = StockLevel.objects.aggregate(avg_pct=Avg("percentage"))
        avg_stock_pct = float(stock_agg["avg_pct"] or 0)

        dispense_trend = []
        for offset in range(6, -1, -1):
            day = today - timedelta(days=offset)
            day_qs = DispenseLog.objects.filter(dispensed_at__date=day)
            dispense_trend.append(
                {
                    "date": day.isoformat(),
                    "count": day_qs.count(),
                    "litres": float(day_qs.aggregate(t=Sum("litres"))["t"] or 0),
                }
            )

        district_rows = (
            stations.values("district")
            .annotate(station_count=Count("id"))
            .order_by("-station_count")
        )
        district_breakdown = []
        for row in district_rows:
            district = row["district"] or "Unknown"
            district_stations = stations.filter(district=row["district"])
            district_stock = StockLevel.objects.filter(station__in=district_stations).aggregate(avg_pct=Avg("percentage"))
            district_red = sum(
                1
                for r in latest_risks.values()
                if r.station.district == row["district"] and r.risk_tier == "red"
            )
            district_breakdown.append(
                {
                    "district": district,
                    "stations": row["station_count"],
                    "avg_stock_pct": round(float(district_stock["avg_pct"] or 0), 1),
                    "red_risks": district_red,
                }
            )

        stock_health = []
        for fuel_code, _label in FUEL_TYPES:
            fuel_stocks = StockLevel.objects.filter(fuel_type=fuel_code)
            agg = fuel_stocks.aggregate(avg_pct=Avg("percentage"))
            below_25 = fuel_stocks.filter(percentage__lt=25).count()
            stock_health.append(
                {
                    "fuel_type": fuel_code,
                    "avg_pct": round(float(agg["avg_pct"] or 0), 1),
                    "below_25": below_25,
                    "tank_count": fuel_stocks.count(),
                }
            )

        role_counts = (
            User.objects.filter(is_active=True)
            .values("role")
            .annotate(count=Count("id"))
            .order_by("role")
        )

        return Response(
            {
                "summary": {
                    "total_stations": total_stations,
                    "dispense_today": dispense_today,
                    "litres_today": litres_today,
                    "red_risk_count": red_count,
                    "amber_risk_count": amber_count,
                    "avg_stock_pct": round(avg_stock_pct, 1),
                },
                "dispense_trend": dispense_trend,
                "district_breakdown": district_breakdown,
                "stock_health": stock_health,
                "role_counts": list(role_counts),
            }
        )
