from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from stations.models import Station

User = get_user_model()


class NetworkAnalyticsTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.station = Station.objects.create(
            name="Test Station",
            district="Colombo",
            latitude=6.9,
            longitude=79.8,
            fuel_types=["petrol_92"],
        )
        cls.admin = User.objects.create_user(
            username="analytics_admin",
            email="analytics_admin@test.lk",
            password="testpass123",
            role=User.Role.ADMIN,
        )
        cls.manager = User.objects.create_user(
            username="analytics_mgr",
            email="analytics_mgr@test.lk",
            password="testpass123",
            role=User.Role.STATION_MANAGER,
            station=cls.station,
        )

    def _auth(self, user):
        token = RefreshToken.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_admin_can_fetch_network_analytics(self):
        self._auth(self.admin)
        res = self.client.get("/api/analytics/network/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("summary", res.data)
        self.assertIn("dispense_trend", res.data)
        self.assertIn("district_breakdown", res.data)

    def test_manager_denied_analytics(self):
        self._auth(self.manager)
        res = self.client.get("/api/analytics/network/")
        self.assertEqual(res.status_code, 403)
