from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import User
from stations.models import Station


class RoleLoginTestCase(TestCase):
    DEMO_PASSWORD = "DemoPass123"

    @classmethod
    def setUpTestData(cls):
        cls.station = Station.objects.create(
            name="Test Station",
            district="Colombo",
            station_type="urban",
            latitude=6.93,
            longitude=79.86,
            fuel_types=["petrol_92"],
        )
        roles = [
            ("driver@demo.fuelsense.lk", User.Role.DRIVER, None),
            ("attendant@demo.fuelsense.lk", User.Role.ATTENDANT, cls.station),
            ("manager@demo.fuelsense.lk", User.Role.STATION_MANAGER, cls.station),
            ("admin@demo.fuelsense.lk", User.Role.ADMIN, None),
            ("superadmin@demo.fuelsense.lk", User.Role.SUPER_ADMIN, None),
        ]
        for email, role, station in roles:
            user = User.objects.create_user(
                username=email.split("@")[0],
                email=email,
                password=cls.DEMO_PASSWORD,
                role=role,
                station=station,
            )
            if role == User.Role.SUPER_ADMIN:
                user.is_superuser = True
                user.is_staff = True
                user.save()

    def test_all_roles_can_login(self):
        client = APIClient()
        for role in User.Role:
            email = f"{role.value.split('_')[0]}@demo.fuelsense.lk"
            if role == User.Role.STATION_MANAGER:
                email = "manager@demo.fuelsense.lk"
            elif role == User.Role.SUPER_ADMIN:
                email = "superadmin@demo.fuelsense.lk"
            elif role == User.Role.ATTENDANT:
                email = "attendant@demo.fuelsense.lk"
            elif role == User.Role.ADMIN:
                email = "admin@demo.fuelsense.lk"
            elif role == User.Role.DRIVER:
                email = "driver@demo.fuelsense.lk"

            response = client.post(
                "/api/auth/login/",
                {"email": email, "password": self.DEMO_PASSWORD},
                format="json",
            )
            self.assertEqual(response.status_code, status.HTTP_200_OK, msg=f"Login failed for {role}")
            self.assertIn("access", response.data)
