from django.urls import path

from .views import NetworkAnalyticsView

urlpatterns = [
    path("network/", NetworkAnalyticsView.as_view(), name="analytics-network"),
]
