import 'dart:convert';

import '../core/api/api_client.dart';

class StationRepository {
  StationRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list({String? district, String? fuelType}) async {
    final res = await _api.get(
      '/stations/',
      query: {
        if (district != null && district.isNotEmpty) 'district': district,
        if (fuelType != null) 'fuel_type': fuelType,
      },
      auth: false,
    );
    if (res.statusCode != 200) throw ApiException('Failed to load stations', res.statusCode);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final res = await _api.get('/stations/$id/', auth: false);
    if (res.statusCode != 200) throw ApiException('Station not found', res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> crowdReports(int stationId) async {
    final res = await _api.get('/stations/$stationId/crowd-reports/', auth: false);
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }
}

class OperationsRepository {
  OperationsRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> dispenseHistory() async {
    final res = await _api.get('/dispense/history/');
    if (res.statusCode != 200) throw ApiException('Failed to load dispense history', res.statusCode);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<List<Map<String, dynamic>>> deliveryHistory({int? stationId}) async {
    final res = await _api.get(
      '/delivery/history/',
      query: stationId == null ? null : {'station_id': stationId.toString()},
    );
    if (res.statusCode != 200) throw ApiException('Failed to load deliveries', res.statusCode);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<Map<String, dynamic>> logDelivery({
    required String fuelType,
    required double litres,
    String? notes,
  }) async {
    final res = await _api.post('/delivery/', {
      'fuel_type': fuelType,
      'litres': litres,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    if (res.statusCode != 201) {
      throw ApiException(parseApiError(res.body), res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class ForecastRepository {
  ForecastRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> stationForecasts(int stationId, {String? fuelType}) async {
    final res = await _api.get(
      '/forecasts/$stationId/',
      query: fuelType == null ? null : {'fuel_type': fuelType},
      auth: false,
    );
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<Map<String, dynamic>> forecastComponents(int stationId, String fuelType) async {
    final res = await _api.get(
      '/forecasts/$stationId/components/',
      query: {'fuel_type': fuelType},
      auth: false,
    );
    if (res.statusCode != 200) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> depletionRisks({
    int? stationId,
    String? fuelType,
    String? riskTier,
  }) async {
    final res = await _api.get(
      '/depletion-risk/',
      query: {
        if (stationId != null) 'station_id': stationId.toString(),
        if (fuelType != null) 'fuel_type': fuelType,
        if (riskTier != null) 'risk_tier': riskTier,
      },
    );
    if (res.statusCode != 200) throw ApiException('Failed to load risks', res.statusCode);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }
}

class CrisisRepository {
  CrisisRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> status() async {
    final res = await _api.get('/crisis/status/', auth: false);
    if (res.statusCode != 200) return {'is_active': false};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> activate({String? message, List<Map<String, dynamic>>? quotas}) async {
    final res = await _api.post('/crisis/activate/', {
      if (message != null) 'message': message,
      if (quotas != null) 'quotas': quotas,
    });
    if (res.statusCode != 201) throw ApiException(parseApiError(res.body), res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deactivate() async {
    final res = await _api.post('/crisis/deactivate/', {});
    if (res.statusCode != 200) throw ApiException(parseApiError(res.body), res.statusCode);
  }
}

class PriceRepository {
  PriceRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> history({String? fuelType}) async {
    final res = await _api.get(
      '/prices/history/',
      query: fuelType == null ? null : {'fuel_type': fuelType},
      auth: false,
    );
    if (res.statusCode != 200) throw ApiException('Failed to load prices', res.statusCode);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<Map<String, dynamic>> create({
    required String fuelType,
    required double pricePerLitre,
    String? source,
    DateTime? effectiveFrom,
  }) async {
    final res = await _api.post('/prices/', {
      'fuel_type': fuelType,
      'price_per_litre': pricePerLitre,
      if (source != null) 'source': source,
      if (effectiveFrom != null) 'effective_from': effectiveFrom.toUtc().toIso8601String(),
    });
    if (res.statusCode != 201) throw ApiException(parseApiError(res.body), res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list() async {
    final res = await _api.get('/auth/users/');
    if (res.statusCode != 200) throw ApiException('Failed to load users', res.statusCode);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final res = await _api.post('/auth/users/', payload);
    if (res.statusCode != 201) throw ApiException(parseApiError(res.body), res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> payload) async {
    final res = await _api.patch('/auth/users/$id/', payload);
    if (res.statusCode != 200) throw ApiException(parseApiError(res.body), res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class AnalyticsRepository {
  AnalyticsRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> network() async {
    final res = await _api.get('/analytics/network/');
    if (res.statusCode != 200) throw ApiException('Failed to load analytics', res.statusCode);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

String parseApiError(String body) {
  try {
    final data = jsonDecode(body);
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      final parts = <String>[];
      data.forEach((key, value) {
        if (value is List) parts.add('$key: ${value.join(', ')}');
        else parts.add('$key: $value');
      });
      if (parts.isNotEmpty) return parts.join('; ');
    }
  } catch (_) {}
  return 'Request failed';
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
