from rest_framework import serializers

from .models import CrisisMode, CrisisQuota


class CrisisQuotaSerializer(serializers.ModelSerializer):
    class Meta:
        model = CrisisQuota
        fields = ("vehicle_type", "fuel_type", "max_litres", "cooldown_hours")


class CrisisModeSerializer(serializers.ModelSerializer):
    quotas = CrisisQuotaSerializer(many=True, read_only=True)

    class Meta:
        model = CrisisMode
        fields = ("id", "is_active", "message", "activated_at", "deactivated_at", "quotas")


class CrisisActivateSerializer(serializers.Serializer):
    message = serializers.CharField(required=False, allow_blank=True, default="")
    quotas = CrisisQuotaSerializer(many=True, required=False)
