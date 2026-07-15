import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/models/models.dart';

class StationRepository {
  StationRepository(this._api);

  final ApiClient _api;

  Future<List<Station>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 15,
    String fuelType = 'petrol_92',
    double? minStock,
  }) async {
    final query = {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius_km': radiusKm.toString(),
      'fuel_type': fuelType,
      if (minStock != null) 'min_stock': minStock.toString(),
      'limit': '20',
    };
    final res = await _api.get('/stations/nearby/', query: query, auth: false);
    if (res.statusCode != 200) throw Exception('Failed to load stations');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['results'] as List).map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> submitCrowdReport({required int stationId, required String fuelType, required String status}) async {
    final res = await _api.post('/crowd-reports/', {
      'station': stationId,
      'fuel_type': fuelType,
      'status': status,
    });
    if (res.statusCode != 201) throw Exception('Crowd report failed');
  }
}

class VehicleRepository {
  VehicleRepository(this._api);

  final ApiClient _api;

  Future<List<Vehicle>> list() async {
    final res = await _api.get('/vehicles/');
    if (res.statusCode != 200) throw Exception('Failed to load vehicles');
    return (jsonDecode(res.body) as List).map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vehicle> create(String plate, String type) async {
    final res = await _api.post('/vehicles/', {'plate_number': plate, 'vehicle_type': type});
    if (res.statusCode != 201) throw Exception('Failed to register vehicle');
    return Vehicle.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deactivate(int id) async {
    await _api.patch('/vehicles/$id/', {'is_active': false});
  }

  Future<Map<String, dynamic>> qrPayload(int id) async {
    final res = await _api.get('/vehicles/$id/qr/');
    if (res.statusCode != 200) throw Exception('QR not found');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class DispenseRepository {
  DispenseRepository(this._api);

  final ApiClient _api;

  Future<List<DispenseRecord>> history() async {
    final res = await _api.get('/dispense/history/');
    if (res.statusCode != 200) throw Exception('Failed to load history');
    return (jsonDecode(res.body) as List).map((e) => DispenseRecord.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class PriceRepository {
  PriceRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> history({String? fuelType}) async {
    final res = await _api.get('/prices/history/', query: fuelType == null ? null : {'fuel_type': fuelType}, auth: false);
    if (res.statusCode != 200) throw Exception('Failed to load prices');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }
}
