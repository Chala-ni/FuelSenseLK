import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = _normalizeBase(
          baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api'),
        );

  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  static String _normalizeBase(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/') || normalized.endsWith('\\')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _storage.read(key: 'access');
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path, {Map<String, String>? query, bool auth = true}) async {
    return http.get(_uri(path, query: query), headers: await _headers(auth: auth));
  }

  Future<http.Response> post(String path, Map<String, dynamic> body, {bool auth = true}) async =>
      http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body));

  Future<http.Response> patch(String path, Map<String, dynamic> body) async =>
      http.patch(_uri(path), headers: await _headers(), body: jsonEncode(body));

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
  }

  Future<void> saveRole(String role) => _storage.write(key: 'role', value: role);
  Future<String?> get role => _storage.read(key: 'role');
  Future<String?> get accessToken => _storage.read(key: 'access');

  Future<void> clear() async {
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

  Future<bool> ensureAuthenticated() async {
    final token = await _storage.read(key: 'access');
    if (token == null) return false;
    var res = await get('/auth/me/');
    if (res.statusCode == 200) return true;
    if (res.statusCode == 401 && await refreshAccessToken()) {
      res = await get('/auth/me/');
      return res.statusCode == 200;
    }
    await clear();
    return false;
  }

  Future<Map<String, dynamic>?> me() async {
    final res = await get('/auth/me/');
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class AuthService {
  AuthService({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post('/auth/login/', {'email': email, 'password': password}, auth: false);
    if (res.statusCode != 200) throw Exception('Invalid email or password');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _api.saveTokens(data['access'] as String, data['refresh'] as String);
    final me = await _api.me();
    if (me == null) throw Exception('Login failed');
    await _api.saveRole(me['role'] as String);
    return me;
  }

  Future<void> logout() => _api.clear();

  ApiClient get api => _api;
}
