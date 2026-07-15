from django.urls import path

from operations.views import DeliveryCreateView, DeliveryListView

urlpatterns = [
    path("", DeliveryCreateView.as_view(), name="delivery-create"),
    path("history/", DeliveryListView.as_view(), name="delivery-list"),
]
