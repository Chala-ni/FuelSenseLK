import 'dart:convert';

import '../../core/api/api_client.dart';

class DispenseRepository {
  DispenseRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> validate({
    required String qrId,
    required String fuelType,
    required double litres,
  }) async {
    final res = await _api.post('/dispense/validate/', {
      'qr_id': qrId,
      'fuel_type': fuelType,
      'litres': litres.toStringAsFixed(2),
    });
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? body.toString());
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> dispense({
    required String qrId,
    required String fuelType,
    required double litres,
  }) async {
    final res = await _api.post('/dispense/', {
      'qr_id': qrId,
      'fuel_type': fuelType,
      'litres': litres.toStringAsFixed(2),
    });
    if (res.statusCode != 201) throw Exception('Dispense failed: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> deliveryHistory() async {
    final res = await _api.get('/delivery/history/');
    if (res.statusCode != 200) throw Exception('Failed to load deliveries');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<Map<String, dynamic>> logDelivery({
    required String fuelType,
    required double litres,
    String notes = '',
  }) async {
    final res = await _api.post('/delivery/', {
      'fuel_type': fuelType,
      'litres': litres.toStringAsFixed(2),
      if (notes.isNotEmpty) 'notes': notes,
    });
    if (res.statusCode != 201) throw Exception('Delivery failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class StationRepository {
  StationRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> getStation(int id) async {
    final res = await _api.get('/stations/$id/', auth: false);
    if (res.statusCode != 200) throw Exception('Station not found');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
