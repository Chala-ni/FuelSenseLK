from rest_framework import generics, permissions
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from stations.models import Station

from .models import DepletionRisk, Forecast
from .serializers import DepletionRiskSerializer, ForecastSerializer
from .services import forecast_components


class StationForecastListView(generics.ListAPIView):
    serializer_class = ForecastSerializer
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        station_id = self.kwargs["station_id"]
        if not Station.objects.filter(pk=station_id, is_active=True).exists():
            raise NotFound("Station not found.")
        qs = Forecast.objects.filter(station_id=station_id).select_related("station")
        fuel_type = self.request.query_params.get("fuel_type")
        if fuel_type:
            qs = qs.filter(fuel_type=fuel_type)
        return qs[:500]


class DepletionRiskListView(generics.ListAPIView):
    serializer_class = DepletionRiskSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        qs = DepletionRisk.objects.select_related("station").order_by("-generated_at")
        station_id = self.request.query_params.get("station_id")
        fuel_type = self.request.query_params.get("fuel_type")
        tier = self.request.query_params.get("risk_tier")
        if station_id:
            qs = qs.filter(station_id=station_id)
        if fuel_type:
            qs = qs.filter(fuel_type=fuel_type)
        if tier:
            qs = qs.filter(risk_tier=tier)
        return qs[:200]


class StationDepletionRiskView(generics.ListAPIView):
    serializer_class = DepletionRiskSerializer
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        station_id = self.kwargs["station_id"]
        if not Station.objects.filter(pk=station_id, is_active=True).exists():
            raise NotFound("Station not found.")
        return DepletionRisk.objects.filter(station_id=station_id).order_by("-generated_at")[:50]


class StationForecastComponentsView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, station_id):
        if not Station.objects.filter(pk=station_id, is_active=True).exists():
            raise NotFound("Station not found.")
        fuel_type = request.query_params.get("fuel_type", "petrol_92")
        return Response(forecast_components(station_id, fuel_type))
