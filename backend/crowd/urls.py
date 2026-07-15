from django.urls import path

from .views import CrowdReportCreateView

urlpatterns = [
    path("", CrowdReportCreateView.as_view(), name="crowd-report-create"),
]
