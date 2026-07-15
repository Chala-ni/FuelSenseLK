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


class Sprint5TestCase(TestCase):
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
        self.other_station = Station.objects.create(
            name="Other Fuel",
            district="Gampaha",
            station_type="urban",
            latitude=7.09,
            longitude=79.99,
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
        self.manager = User.objects.create_user(
            username="manager",
            email="manager@test.com",
            password="testpass123",
            role=User.Role.STATION_MANAGER,
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

    def test_dispense_validate_ok(self):
        self._login("attendant@test.com")
        response = self.client.post(
            "/api/dispense/validate/",
            {"qr_id": str(self.vehicle.qr_id), "fuel_type": "petrol_92", "litres": "10.00"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["valid"])
        self.assertEqual(response.data["vehicle"]["plate_number"], "ABC-1234")

    def test_dispense_validate_crisis_blocked(self):
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
            "/api/dispense/validate/",
            {"qr_id": str(self.vehicle.qr_id), "fuel_type": "petrol_92", "litres": "10.00"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["valid"])
        self.assertEqual(response.data["blocked_reason"], "crisis_quota_exceeded")

    def test_manager_dashboard(self):
        self._login("manager@test.com")
        response = self.client.get("/api/manager/dashboard/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["station"]["name"], "Test Fuel")
        self.assertIn("dispense_today", response.data)
        self.assertIn("recent_deliveries", response.data)

    def test_manager_creates_attendant_only(self):
        self._login("manager@test.com")
        ok = self.client.post(
            "/api/auth/users/",
            {
                "email": "new_att@test.com",
                "username": "new_att",
                "password": "testpass123",
                "role": "attendant",
                "station": self.station.id,
            },
            format="json",
        )
        self.assertEqual(ok.status_code, status.HTTP_201_CREATED)

        bad = self.client.post(
            "/api/auth/users/",
            {
                "email": "new_mgr@test.com",
                "username": "new_mgr",
                "password": "testpass123",
                "role": "station_manager",
                "station": self.station.id,
            },
            format="json",
        )
        self.assertEqual(bad.status_code, status.HTTP_400_BAD_REQUEST)

    def test_manager_cannot_create_staff_for_other_station(self):
        self._login("manager@test.com")
        response = self.client.post(
            "/api/auth/users/",
            {
                "email": "other_att@test.com",
                "username": "other_att",
                "password": "testpass123",
                "role": "attendant",
                "station": self.other_station.id,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_attendant_can_list_delivery_history(self):
        self._login("attendant@test.com")
        self.client.post(
            "/api/delivery/",
            {"fuel_type": "petrol_92", "litres": "500.00"},
            format="json",
        )
        response = self.client.get("/api/delivery/history/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
