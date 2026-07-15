from django.urls import path

from .views import NearbyStationsView, StationDetailView, StationListView
from crowd.views import StationCrowdReportListView

urlpatterns = [
    path("", StationListView.as_view(), name="station-list"),
    path("nearby/", NearbyStationsView.as_view(), name="station-nearby"),
    path("<int:pk>/", StationDetailView.as_view(), name="station-detail"),
    path("<int:station_id>/crowd-reports/", StationCrowdReportListView.as_view(), name="station-crowd-reports"),
]
