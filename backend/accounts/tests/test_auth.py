from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import User
from stations.models import Station


class AuthAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = "/api/auth/register/"
        self.login_url = "/api/auth/login/"
        self.me_url = "/api/auth/me/"

    def test_register_login_and_me(self):
        register_payload = {
            "email": "driver@example.com",
            "username": "driver1",
            "password": "securepass1",
            "first_name": "Test",
            "last_name": "Driver",
        }
        response = self.client.post(self.register_url, register_payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["email"], "driver@example.com")

        login_response = self.client.post(
            self.login_url,
            {"email": "driver@example.com", "password": "securepass1"},
            format="json",
        )
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        self.assertIn("access", login_response.data)
        self.assertIn("refresh", login_response.data)

        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {login_response.data['access']}")
        me_response = self.client.get(self.me_url)
        self.assertEqual(me_response.status_code, status.HTTP_200_OK)
        self.assertEqual(me_response.data["role"], User.Role.DRIVER)
