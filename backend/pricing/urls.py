from django.urls import path

from .views import PriceHistoryCreateView, PriceHistoryListView

urlpatterns = [
    path("history/", PriceHistoryListView.as_view(), name="price-history"),
    path("", PriceHistoryCreateView.as_view(), name="price-create"),
]
