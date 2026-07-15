from django.utils import timezone
from rest_framework import generics, permissions

from .models import CrowdReport
from .serializers import CrowdReportCreateSerializer, CrowdReportSerializer


class CrowdReportCreateView(generics.CreateAPIView):
    serializer_class = CrowdReportCreateSerializer
    permission_classes = (permissions.IsAuthenticated,)


class StationCrowdReportListView(generics.ListAPIView):
    serializer_class = CrowdReportSerializer
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        now = timezone.now()
        return CrowdReport.objects.filter(
            station_id=self.kwargs["station_id"],
            expires_at__gt=now,
        ).order_by("-reported_at")
