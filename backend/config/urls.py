from django.urls import path, include

from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from django.contrib import admin
from django.http import JsonResponse


def health(_request):
    return JsonResponse({"status": "ok", "service": "fuelsense-api"})


urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", health),
    path("api/auth/", include("accounts.urls")),
    path("api/stations/", include("stations.urls")),
    path("api/manager/", include("stations.manager_urls")),
    path("api/vehicles/", include("vehicles.urls")),
    path("api/dispense/", include("operations.urls")),
    path("api/delivery/", include("operations.delivery_urls")),
    path("api/crowd-reports/", include("crowd.urls")),
    path("api/crisis/", include("crisis.urls")),
    path("api/prices/", include("pricing.urls")),
    path("api/analytics/", include("analytics.urls")),
    path("api/", include("forecasting.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]
