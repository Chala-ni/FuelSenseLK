"""Broadcast stock updates to WebSocket subscribers."""

from django.utils import timezone

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from stations.models import StockLevel


def stock_colour(percentage: float) -> str:
    if percentage <= 0:
        return "red"
    if percentage < 20:
        return "amber"
    if percentage < 50:
        return "amber"
    return "green"


def stock_payload(station_id: int, stock: StockLevel) -> dict:
    pct = float(stock.percentage)
    return {
        "station_id": station_id,
        "fuel_type": stock.fuel_type,
        "current_litres": float(stock.current_litres),
        "percentage": pct,
        "colour": stock_colour(pct),
        "timestamp": timezone.now().isoformat(),
    }


def broadcast_stock_update(station_id: int, stock: StockLevel) -> None:
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    payload = stock_payload(station_id, stock)
    async_to_sync(channel_layer.group_send)(
        f"station_{station_id}",
        {"type": "stock_update", "payload": payload},
    )
