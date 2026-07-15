from django.urls import path

from .views import CrisisActivateView, CrisisDeactivateView, CrisisStatusView

urlpatterns = [
    path("status/", CrisisStatusView.as_view(), name="crisis-status"),
    path("activate/", CrisisActivateView.as_view(), name="crisis-activate"),
    path("deactivate/", CrisisDeactivateView.as_view(), name="crisis-deactivate"),
]
