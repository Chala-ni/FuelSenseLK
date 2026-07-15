from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from core.permissions import IsAttendantOrManager, IsAdminOrManager

from .models import DeliveryLog, DispenseLog
from .serializers import (
    DeliveryCreateSerializer,
    DeliveryLogSerializer,
    DispenseCreateSerializer,
    DispenseLogSerializer,
    DispenseValidateSerializer,
)


class DispenseValidateView(APIView):
    permission_classes = (IsAttendantOrManager,)

    def post(self, request):
        serializer = DispenseValidateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        return Response(serializer.validated_data)


class DispenseCreateView(APIView):
    permission_classes = (IsAttendantOrManager,)

    def post(self, request):
        serializer = DispenseCreateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        receipt = serializer.save()
        return Response(receipt, status=201)


class DispenseHistoryView(generics.ListAPIView):
    serializer_class = DispenseLogSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        user = self.request.user
        qs = DispenseLog.objects.select_related("station", "vehicle").order_by("-dispensed_at")
        if user.role == User.Role.DRIVER:
            return qs.filter(vehicle__owner=user)
        if user.role == User.Role.ATTENDANT:
            return qs.filter(station=user.station)
        if user.role == User.Role.STATION_MANAGER:
            return qs.filter(station=user.station)
        return qs


class DeliveryCreateView(generics.CreateAPIView):
    serializer_class = DeliveryCreateSerializer
    permission_classes = (IsAttendantOrManager,)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log = serializer.save()
        data = DeliveryLogSerializer(log).data
        stock = getattr(log, "_stock_snapshot", None)
        if stock:
            data["stock"] = {
                "current_litres": float(stock.current_litres),
                "percentage": float(stock.percentage),
            }
        return Response(data, status=201)


class DeliveryListView(generics.ListAPIView):
    serializer_class = DeliveryLogSerializer
    permission_classes = (IsAttendantOrManager,)

    def get_queryset(self):
        user = self.request.user
        qs = DeliveryLog.objects.select_related("station").order_by("-delivered_at")
        if user.role in (User.Role.STATION_MANAGER, User.Role.ATTENDANT):
            return qs.filter(station=user.station)
        station_id = self.request.query_params.get("station_id")
        if station_id:
            qs = qs.filter(station_id=station_id)
        return qs
