from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import User
from crisis.models import CrisisMode
from crowd.models import CrowdReport
from forecasting.models import DepletionRisk, Forecast
from forecasting.services import refresh_depletion_risk, refresh_prophet_forecasts
from stations.models import Station, StockLevel


class Sprint3APITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.station = Station.objects.create(
            name="Colombo Test",
            district="Colombo",
            station_type="urban",
            latitude=6.93,
            longitude=79.86,
            fuel_types=["petrol_92"],
        )
        StockLevel.objects.create(
            station=self.station,
            fuel_type="petrol_92",
            current_litres=Decimal("8000"),
            percentage=Decimal("80"),
        )
        self.driver = User.objects.create_user(
            username="driver2",
            email="driver2@test.com",
            password="testpass123",
            role=User.Role.DRIVER,
        )
        self.admin = User.objects.create_user(
            username="admin2",
            email="admin2@test.com",
            password="testpass123",
            role=User.Role.ADMIN,
            is_staff=True,
        )

    def _login(self, email):
        res = self.client.post("/api/auth/login/", {"email": email, "password": "testpass123"}, format="json")
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {res.data['access']}")

    def test_crowd_report_creates_with_expiry(self):
        self._login("driver2@test.com")
        response = self.client.post(
            "/api/crowd-reports/",
            {"station": self.station.id, "fuel_type": "petrol_92", "status": "low"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        report = CrowdReport.objects.get(pk=response.data["id"])
        self.assertIsNotNone(report.expires_at)
        self.assertGreater(report.expires_at, timezone.now())

    def test_crisis_status_inactive_by_default(self):
        response = self.client.get("/api/crisis/status/")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data.get("is_active", False))

    def test_crisis_activate(self):
        self._login("admin2@test.com")
        response = self.client.post(
            "/api/crisis/activate/",
            {
                "message": "Fuel shortage",
                "quotas": [{"vehicle_type": "car", "fuel_type": "petrol_92", "max_litres": "20.00", "cooldown_hours": 24}],
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertTrue(CrisisMode.objects.filter(is_active=True).exists())

    def test_nearby_min_stock_filter(self):
        Station.objects.create(
            name="Low Stock",
            district="Colombo",
            station_type="urban",
            latitude=6.931,
            longitude=79.861,
            fuel_types=["petrol_92"],
        )
        low = Station.objects.get(name="Low Stock")
        StockLevel.objects.create(station=low, fuel_type="petrol_92", current_litres=100, percentage=Decimal("5"))

        response = self.client.get(
            "/api/stations/nearby/",
            {"lat": 6.93, "lng": 79.86, "radius_km": 5, "fuel_type": "petrol_92", "min_stock": 50},
        )
        self.assertEqual(response.status_code, 200)
        names = [r["name"] for r in response.data["results"]]
        self.assertIn("Colombo Test", names)
        self.assertNotIn("Low Stock", names)

    def test_forecast_seed_services(self):
        self.assertGreater(refresh_prophet_forecasts(), 0)
        self.assertGreater(refresh_depletion_risk(), 0)
        self.assertTrue(Forecast.objects.exists())
        self.assertTrue(DepletionRisk.objects.exists())

    def test_forecast_components_endpoint(self):
        refresh_prophet_forecasts()
        response = self.client.get(f"/api/forecasts/{self.station.id}/components/?fuel_type=petrol_92")
        self.assertEqual(response.status_code, 200)
        self.assertIn("trend", response.data)
