from rest_framework import generics, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import haversine_km

from .filters import filter_by_fuel_type
from .models import Station
from .serializers import NearbyStationSerializer, StationDetailSerializer, StationListSerializer


class StationListView(generics.ListAPIView):
    serializer_class = StationListSerializer
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        qs = Station.objects.filter(is_active=True).prefetch_related("stock_levels")
        district = self.request.query_params.get("district")
        fuel_type = self.request.query_params.get("fuel_type")
        if district:
            qs = qs.filter(district__iexact=district)
        if fuel_type:
            qs = filter_by_fuel_type(qs, fuel_type)
        return qs


class StationDetailView(generics.RetrieveAPIView):
    serializer_class = StationDetailSerializer
    permission_classes = (permissions.AllowAny,)
    queryset = Station.objects.prefetch_related("stock_levels")


class NearbyStationsView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        try:
            lat = float(request.query_params["lat"])
            lng = float(request.query_params["lng"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValidationError({"detail": "Query params `lat` and `lng` are required floats."}) from exc

        try:
            radius_km = float(request.query_params.get("radius_km", 15))
        except ValueError as exc:
            raise ValidationError({"radius_km": "Must be a number."}) from exc

        limit = min(int(request.query_params.get("limit", 20)), 50)
        fuel_type = request.query_params.get("fuel_type")
        min_stock = request.query_params.get("min_stock")

        stations = Station.objects.filter(is_active=True).prefetch_related("stock_levels")
        if fuel_type:
            stations = filter_by_fuel_type(stations, fuel_type)

        results = []
        for station in stations:
            distance = haversine_km(lat, lng, station.latitude, station.longitude)
            if distance > radius_km:
                continue
            if min_stock is not None and fuel_type:
                try:
                    threshold = float(min_stock)
                except ValueError as exc:
                    raise ValidationError({"min_stock": "Must be a number."}) from exc
                stock = next((s for s in station.stock_levels.all() if s.fuel_type == fuel_type), None)
                if not stock or float(stock.percentage) < threshold:
                    continue
            results.append((distance, station))

        results.sort(key=lambda item: item[0])
        results = results[:limit]

        payload = []
        for distance, station in results:
            data = NearbyStationSerializer(station).data
            data["distance_km"] = round(distance, 2)
            payload.append(data)

        return Response({"count": len(payload), "results": payload})
