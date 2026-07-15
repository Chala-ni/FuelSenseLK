from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from core.permissions import haversine_km
from stations.models import Station


class HaversineTestCase(TestCase):
    def test_zero_distance(self):
        self.assertAlmostEqual(haversine_km(6.9, 79.9, 6.9, 79.9), 0.0, places=5)


class NearbyStationsAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        Station.objects.create(
            name="Colombo Central",
            district="Colombo",
            station_type="urban",
            latitude=6.9271,
            longitude=79.8612,
            fuel_types=["petrol_92"],
        )
        Station.objects.create(
            name="Kandy Hills",
            district="Kandy",
            station_type="urban",
            latitude=7.2906,
            longitude=80.6337,
            fuel_types=["petrol_92"],
        )

    def test_nearby_returns_sorted_by_distance(self):
        response = self.client.get(
            "/api/stations/nearby/",
            {"lat": 6.93, "lng": 79.86, "radius_km": 50},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["name"], "Colombo Central")
        self.assertIn("distance_km", response.data["results"][0])

    def test_nearby_requires_lat_lng(self):
        response = self.client.get("/api/stations/nearby/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
