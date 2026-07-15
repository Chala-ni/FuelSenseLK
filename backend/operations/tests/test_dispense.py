from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import User
from crisis.models import CrisisMode, CrisisQuota
from pricing.models import PriceHistory
from stations.models import Station, StockLevel
from vehicles.models import Vehicle


class DispenseFlowTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.station = Station.objects.create(
            name="Test Fuel",
            district="Colombo",
            station_type="urban",
            latitude=6.93,
            longitude=79.86,
            fuel_types=["petrol_92"],
            tank_capacity_litres=10000,
        )
        StockLevel.objects.create(
            station=self.station,
            fuel_type="petrol_92",
            current_litres=Decimal("5000"),
            percentage=Decimal("50"),
        )
        PriceHistory.objects.create(
            fuel_type="petrol_92",
            price_per_litre=Decimal("363.00"),
            effective_from=timezone.now().date(),
        )
        self.driver = User.objects.create_user(
            username="driver",
            email="driver@test.com",
            password="testpass123",
            role=User.Role.DRIVER,
        )
        self.attendant = User.objects.create_user(
            username="attendant",
            email="attendant@test.com",
            password="testpass123",
            role=User.Role.ATTENDANT,
            station=self.station,
        )
        self.vehicle = Vehicle.objects.create(
            owner=self.driver,
            plate_number="ABC-1234",
            vehicle_type="car",
        )

    def _login(self, email):
        res = self.client.post("/api/auth/login/", {"email": email, "password": "testpass123"}, format="json")
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")

    def test_dispense_deducts_stock(self):
        self._login("attendant@test.com")
        response = self.client.post(
            "/api/dispense/",
            {"qr_id": str(self.vehicle.qr_id), "fuel_type": "petrol_92", "litres": "10.00"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["litres"], 10.0)
        stock = StockLevel.objects.get(station=self.station, fuel_type="petrol_92")
        self.assertEqual(float(stock.current_litres), 4990.0)

    def test_crisis_quota_blocks_dispense(self):
        crisis = CrisisMode.objects.create(is_active=True, message="Test crisis")
        CrisisQuota.objects.create(
            crisis=crisis,
            vehicle_type="car",
            fuel_type="petrol_92",
            max_litres=Decimal("5"),
            cooldown_hours=24,
        )
        self._login("attendant@test.com")
        response = self.client.post(
            "/api/dispense/",
            {"qr_id": str(self.vehicle.qr_id), "fuel_type": "petrol_92", "litres": "10.00"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_delivery_increases_stock(self):
        self._login("attendant@test.com")
        response = self.client.post(
            "/api/delivery/",
            {"fuel_type": "petrol_92", "litres": "1000.00"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        stock = StockLevel.objects.get(station=self.station, fuel_type="petrol_92")
        self.assertEqual(float(stock.current_litres), 6000.0)
