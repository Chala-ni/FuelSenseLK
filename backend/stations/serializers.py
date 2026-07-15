from rest_framework import serializers

from .models import Station, StockLevel


class StockLevelSerializer(serializers.ModelSerializer):
    class Meta:
        model = StockLevel
        fields = ("fuel_type", "current_litres", "percentage", "last_updated")


class StationListSerializer(serializers.ModelSerializer):
    stock_levels = StockLevelSerializer(many=True, read_only=True)

    class Meta:
        model = Station
        fields = (
            "id",
            "name",
            "address",
            "district",
            "station_type",
            "latitude",
            "longitude",
            "fuel_types",
            "is_active",
            "stock_levels",
        )


class StationDetailSerializer(StationListSerializer):
    class Meta(StationListSerializer.Meta):
        fields = StationListSerializer.Meta.fields + (
            "tank_capacity_litres",
            "tank_capacities",
            "created_at",
        )


class NearbyStationSerializer(StationListSerializer):
    distance_km = serializers.FloatField(read_only=True)

    class Meta(StationListSerializer.Meta):
        fields = StationListSerializer.Meta.fields + ("distance_km",)
