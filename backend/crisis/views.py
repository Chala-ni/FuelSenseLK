from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.response import Response

from core.permissions import IsAdmin

from .models import CrisisMode, CrisisQuota
from .serializers import CrisisActivateSerializer, CrisisModeSerializer


class CrisisStatusView(generics.RetrieveAPIView):
    serializer_class = CrisisModeSerializer
    permission_classes = (permissions.AllowAny,)

    def get_object(self):
        return CrisisMode.objects.filter(is_active=True).prefetch_related("quotas").order_by("-activated_at").first()

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if not instance:
            return Response({"is_active": False, "message": "Crisis mode is off"})
        return Response(self.get_serializer(instance).data)


class CrisisActivateView(generics.GenericAPIView):
    permission_classes = (IsAdmin,)
    serializer_class = CrisisActivateSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        CrisisMode.objects.filter(is_active=True).update(is_active=False)
        crisis = CrisisMode.objects.create(
            is_active=True,
            activated_by=request.user,
            message=serializer.validated_data.get("message", ""),
        )
        for q in serializer.validated_data.get("quotas", []):
            CrisisQuota.objects.create(crisis=crisis, **q)

        return Response(CrisisModeSerializer(crisis).data, status=201)


class CrisisDeactivateView(generics.GenericAPIView):
    permission_classes = (IsAdmin,)

    def post(self, request):
        updated = CrisisMode.objects.filter(is_active=True).update(
            is_active=False,
            deactivated_at=timezone.now(),
        )
        return Response({"deactivated": updated})
