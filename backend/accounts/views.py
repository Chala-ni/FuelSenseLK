from django.contrib.auth import get_user_model
from rest_framework import generics, permissions
from rest_framework.response import Response

from core.permissions import IsAdminOrManager

from .serializers import (
    AdminUserCreateSerializer,
    RegisterSerializer,
    UserSerializer,
    UserUpdateSerializer,
)

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = (permissions.AllowAny,)


class MeView(generics.RetrieveUpdateAPIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get_serializer_class(self):
        if self.request.method in ("PUT", "PATCH"):
            return UserUpdateSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user


class UserListCreateView(generics.ListCreateAPIView):
    permission_classes = (IsAdminOrManager,)

    def get_serializer_class(self):
        if self.request.method == "POST":
            return AdminUserCreateSerializer
        return UserSerializer

    def get_queryset(self):
        user = self.request.user
        qs = User.objects.select_related("station").order_by("-date_joined")
        if user.role == User.Role.STATION_MANAGER:
            return qs.filter(station=user.station, role=User.Role.ATTENDANT)
        return qs


class UserDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = (IsAdminOrManager,)
    serializer_class = UserSerializer
    lookup_url_kwarg = "user_id"

    def get_queryset(self):
        user = self.request.user
        qs = User.objects.select_related("station")
        if user.role == User.Role.STATION_MANAGER:
            return qs.filter(station=user.station, role=User.Role.ATTENDANT)
        return qs

    def patch(self, request, *args, **kwargs):
        instance = self.get_object()
        if "is_active" in request.data and request.user.role == User.Role.STATION_MANAGER:
            instance.is_active = request.data["is_active"]
            instance.save(update_fields=["is_active"])
            return Response(UserSerializer(instance).data)
        return super().patch(request, *args, **kwargs)
