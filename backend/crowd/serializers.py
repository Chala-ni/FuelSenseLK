from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from .models import CrowdReport


class CrowdReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = CrowdReport
        fields = ("id", "station", "fuel_type", "status", "queue_length", "notes", "expires_at")
        read_only_fields = ("id", "expires_at")

    def create(self, validated_data):
        validated_data["reporter"] = self.context["request"].user
        validated_data["expires_at"] = timezone.now() + timedelta(hours=2)
        return super().create(validated_data)


class CrowdReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = CrowdReport
        fields = (
            "id",
            "station",
            "fuel_type",
            "status",
            "queue_length",
            "notes",
            "reported_at",
            "expires_at",
            "is_verified",
        )
