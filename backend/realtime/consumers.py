from channels.generic.websocket import AsyncJsonWebsocketConsumer


class StockUpdateConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket consumer for live stock updates (Sprint 3 dispense/delivery will publish)."""

    async def connect(self):
        user = self.scope.get("user")
        if user is None or not user.is_authenticated:
            await self.close(code=4001)
            return
        self.station_id = self.scope["url_route"]["kwargs"]["station_id"]
        self.group_name = f"station_{self.station_id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.send_json(
            {
                "type": "connection.established",
                "station_id": int(self.station_id),
                "message": "Subscribed to stock updates",
            }
        )

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def stock_update(self, event):
        await self.send_json(event["payload"])
