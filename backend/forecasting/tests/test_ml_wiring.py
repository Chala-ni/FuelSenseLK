from django.test import TestCase

from forecasting.ml_inference import models_available, resolve_ml_station_id
from stations.models import Station


class MLWiringTestCase(TestCase):
    def test_models_available_paths(self):
        status = models_available()
        self.assertIn("lstm", status)
        self.assertIn("prophet", status)

    def test_resolve_ml_station_id_from_field(self):
        station = Station.objects.create(
            name="FuelSense Station 042",
            ml_station_id=42,
            district="Colombo",
            station_type="urban",
            latitude=6.93,
            longitude=79.86,
            fuel_types=["petrol_92"],
        )
        self.assertEqual(resolve_ml_station_id(station), 42)

    def test_resolve_ml_station_id_from_name(self):
        station = Station.objects.create(
            name="FuelSense Station 007",
            district="Colombo",
            station_type="urban",
            latitude=6.93,
            longitude=79.86,
            fuel_types=["petrol_92"],
        )
        self.assertEqual(resolve_ml_station_id(station), 7)
