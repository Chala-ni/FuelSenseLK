from rest_framework import serializers

from .models import PriceHistory


class PriceHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PriceHistory
        fields = ("id", "fuel_type", "price_per_litre", "effective_from", "source", "created_at")


class PriceHistoryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PriceHistory
        fields = ("fuel_type", "price_per_litre", "effective_from", "source")
