from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework import serializers

from pricing.models import PriceHistory

from .models import DeliveryLog, DispenseLog
from .services import validate_dispense_request


def latest_price(fuel_type: str) -> Decimal | None:
    row = PriceHistory.objects.filter(fuel_type=fuel_type).order_by("-effective_from").first()
    return row.price_per_litre if row else None


class DispenseValidateSerializer(serializers.Serializer):
    qr_id = serializers.UUIDField()
    fuel_type = serializers.CharField(max_length=20)
    litres = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))

    def validate(self, attrs):
        return validate_dispense_request(
            self.context["request"].user,
            attrs["qr_id"],
            attrs["fuel_type"],
            attrs["litres"],
        )


class DispenseCreateSerializer(serializers.Serializer):
    qr_id = serializers.UUIDField()
    fuel_type = serializers.CharField(max_length=20)
    litres = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))

    def validate(self, attrs):
        result = validate_dispense_request(
            self.context["request"].user,
            attrs["qr_id"],
            attrs["fuel_type"],
            attrs["litres"],
        )
        if not result["valid"]:
            raise serializers.ValidationError({"quota": "Crisis quota exceeded.", "details": result["quota"]})
        from vehicles.models import Vehicle

        attrs["vehicle"] = Vehicle.objects.get(qr_id=attrs["qr_id"])
        attrs["station"] = self.context["request"].user.station
        attrs["quota_info"] = result["quota"]
        return attrs

    def create(self, validated_data):
        from core.broadcast import broadcast_stock_update
        from core.stock import apply_stock_delta

        user = self.context["request"].user
        vehicle = validated_data["vehicle"]
        station = validated_data["station"]
        fuel_type = validated_data["fuel_type"]
        litres = validated_data["litres"]
        price = latest_price(fuel_type)

        with transaction.atomic():
            log = DispenseLog.objects.create(
                station=station,
                attendant=user,
                vehicle=vehicle,
                fuel_type=fuel_type,
                litres=litres,
                price_per_litre=price,
            )
            stock = apply_stock_delta(station, fuel_type, -litres)

        broadcast_stock_update(station.id, stock)

        total = (price * litres) if price else None
        return {
            "dispense_id": log.id,
            "station_id": station.id,
            "station_name": station.name,
            "vehicle_plate": vehicle.plate_number,
            "fuel_type": fuel_type,
            "litres": float(litres),
            "price_per_litre": float(price) if price else None,
            "total_price": float(total) if total else None,
            "dispensed_at": log.dispensed_at,
            "stock": {
                "current_litres": float(stock.current_litres),
                "percentage": float(stock.percentage),
            },
            "quota": validated_data.get("quota_info") or {},
        }


class DispenseLogSerializer(serializers.ModelSerializer):
    station_name = serializers.CharField(source="station.name", read_only=True)
    vehicle_plate = serializers.CharField(source="vehicle.plate_number", read_only=True, default="")

    class Meta:
        model = DispenseLog
        fields = (
            "id",
            "station",
            "station_name",
            "vehicle",
            "vehicle_plate",
            "fuel_type",
            "litres",
            "price_per_litre",
            "dispensed_at",
        )


class DeliveryCreateSerializer(serializers.ModelSerializer):
    delivered_at = serializers.DateTimeField(required=False)

    class Meta:
        model = DeliveryLog
        fields = ("fuel_type", "litres", "delivered_at", "notes")

    def validate(self, attrs):
        user = self.context["request"].user
        if user.role not in ("attendant", "station_manager", "admin", "super_admin"):
            raise serializers.ValidationError("Only station staff can log deliveries.")
        station = user.station
        if user.role in ("attendant", "station_manager") and not station:
            raise serializers.ValidationError("No station assigned.")
        if attrs["fuel_type"] not in (station.fuel_types if station else []):
            raise serializers.ValidationError({"fuel_type": "Fuel type not sold at this station."})
        attrs["station"] = station
        return attrs

    def create(self, validated_data):
        from core.broadcast import broadcast_stock_update
        from core.stock import apply_stock_delta

        user = self.context["request"].user
        station = validated_data.pop("station")
        if not validated_data.get("delivered_at"):
            validated_data["delivered_at"] = timezone.now()

        with transaction.atomic():
            log = DeliveryLog.objects.create(station=station, recorded_by=user, **validated_data)
            stock = apply_stock_delta(station, log.fuel_type, log.litres)

        broadcast_stock_update(station.id, stock)
        log._stock_snapshot = stock  # noqa: SLF001
        return log


class DeliveryLogSerializer(serializers.ModelSerializer):
    station_name = serializers.CharField(source="station.name", read_only=True)

    class Meta:
        model = DeliveryLog
        fields = (
            "id",
            "station",
            "station_name",
            "fuel_type",
            "litres",
            "delivered_at",
            "notes",
            "created_at",
        )
