from django.urls import path

from .views import (
    DepletionRiskListView,
    StationDepletionRiskView,
    StationForecastComponentsView,
    StationForecastListView,
)

urlpatterns = [
    path("forecasts/<int:station_id>/", StationForecastListView.as_view(), name="station-forecasts"),
    path("forecasts/<int:station_id>/components/", StationForecastComponentsView.as_view(), name="station-forecast-components"),
    path("depletion-risk/", DepletionRiskListView.as_view(), name="depletion-risk-list"),
    path("depletion-risk/<int:station_id>/", StationDepletionRiskView.as_view(), name="station-depletion-risk"),
]
