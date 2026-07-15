from django.urls import path

from .manager_views import ManagerDashboardView

urlpatterns = [
    path("dashboard/", ManagerDashboardView.as_view(), name="manager-dashboard"),
]
