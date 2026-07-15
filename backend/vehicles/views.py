from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Vehicle
from .serializers import VehicleCreateSerializer, VehicleSerializer, VehicleUpdateSerializer


class VehicleListCreateView(generics.ListCreateAPIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get_serializer_class(self):
        if self.request.method == "POST":
            return VehicleCreateSerializer
        return VehicleSerializer

    def get_queryset(self):
        return Vehicle.objects.filter(owner=self.request.user, is_active=True)


class VehicleDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get_serializer_class(self):
        if self.request.method in ("PUT", "PATCH"):
            return VehicleUpdateSerializer
        return VehicleSerializer

    def get_queryset(self):
        return Vehicle.objects.filter(owner=self.request.user)

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save(update_fields=["is_active"])

    def delete(self, request, *args, **kwargs):
        instance = self.get_object()
        self.perform_destroy(instance)
        return Response(status=status.HTTP_204_NO_CONTENT)


class VehicleQRView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, pk):
        vehicle = Vehicle.objects.filter(owner=request.user, pk=pk, is_active=True).first()
        if not vehicle:
            return Response({"detail": "Not found."}, status=404)
        return Response(
            {
                "vehicle_id": vehicle.id,
                "plate_number": vehicle.plate_number,
                "vehicle_type": vehicle.vehicle_type,
                "qr_id": str(vehicle.qr_id),
                "qr_payload": f"fuelsense:vehicle:{vehicle.qr_id}",
            }
        )
