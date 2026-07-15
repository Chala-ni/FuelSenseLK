from rest_framework import generics, permissions

from core.permissions import IsAdmin

from .models import PriceHistory
from .serializers import PriceHistoryCreateSerializer, PriceHistorySerializer


class PriceHistoryListView(generics.ListAPIView):
    serializer_class = PriceHistorySerializer
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        qs = PriceHistory.objects.all()
        fuel_type = self.request.query_params.get("fuel_type")
        if fuel_type:
            qs = qs.filter(fuel_type=fuel_type)
        return qs


class PriceHistoryCreateView(generics.CreateAPIView):
    serializer_class = PriceHistoryCreateSerializer
    permission_classes = (IsAdmin,)
