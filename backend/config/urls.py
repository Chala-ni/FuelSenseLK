"""FuelSense LK backend URL configuration."""

from django.contrib import admin
from django.http import JsonResponse
from django.urls import path


def health(_request):
    return JsonResponse({"status": "ok", "service": "fuelsense-api"})


urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", health),
]
