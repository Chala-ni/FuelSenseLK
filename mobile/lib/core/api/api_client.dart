import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api');

  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.read(key: 'access');
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path, {Map<String, String>? query, bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return http.get(uri, headers: await _headers(auth: auth));
  }

  Future<http.Response> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    return http.post(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth), body: jsonEncode(body));
  }

  Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    return http.patch(Uri.parse('$baseUrl$path'), headers: await _headers(), body: jsonEncode(body));
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
  }

  Future<void> saveRole(String role) => _storage.write(key: 'role', value: role);

  Future<String?> get accessToken => _storage.read(key: 'access');
  Future<String?> get role => _storage.read(key: 'role');

  Future<void> clearSession() async {
    await _storage.delete(key: 'access');
    await _storage.delete(key: 'refresh');
    await _storage.delete(key: 'role');
  }

  Future<bool> refreshAccessToken() async {
    final refresh = await _storage.read(key: 'refresh');
    if (refresh == null) return false;
    final res = await post('/auth/refresh/', {'refresh': refresh}, auth: false);
    if (res.statusCode != 200) return false;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _storage.write(key: 'access', value: data['access'] as String);
    return true;
  }
}
