from django.urls import path

from .consumers import StockUpdateConsumer

websocket_urlpatterns = [
    path("ws/stations/<int:station_id>/", StockUpdateConsumer.as_asgi()),
]
