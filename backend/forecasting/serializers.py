from rest_framework import serializers

from .models import DepletionRisk, Forecast


class ForecastSerializer(serializers.ModelSerializer):
    class Meta:
        model = Forecast
        fields = (
            "id",
            "station",
            "fuel_type",
            "horizon_hours",
            "predicted_demand_litres",
            "model_name",
            "generated_at",
        )


class DepletionRiskSerializer(serializers.ModelSerializer):
    station_name = serializers.CharField(source="station.name", read_only=True)
    district = serializers.CharField(source="station.district", read_only=True)

    class Meta:
        model = DepletionRisk
        fields = (
            "id",
            "station",
            "station_name",
            "district",
            "fuel_type",
            "horizon_hours",
            "risk_score",
            "risk_tier",
            "estimated_hours_to_empty",
            "model_name",
            "generated_at",
        )
