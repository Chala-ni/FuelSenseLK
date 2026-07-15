from django.urls import path

from .views import DispenseCreateView, DispenseHistoryView, DispenseValidateView

urlpatterns = [
    path("validate/", DispenseValidateView.as_view(), name="dispense-validate"),
    path("", DispenseCreateView.as_view(), name="dispense-create"),
    path("history/", DispenseHistoryView.as_view(), name="dispense-history"),
]
