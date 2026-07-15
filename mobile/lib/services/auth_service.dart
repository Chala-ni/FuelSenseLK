import 'dart:convert';

import '../core/api/api_client.dart';

class AuthService {
  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post('/auth/login/', {'email': email, 'password': password}, auth: false);
    if (res.statusCode != 200) throw Exception('Login failed');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _api.saveTokens(data['access'] as String, data['refresh'] as String);
    final me = await meProfile();
    await _api.saveRole(me['role'] as String);
    return me;
  }

  Future<Map<String, dynamic>> register(String email, String username, String password) async {
    final res = await _api.post('/auth/register/', {
      'email': email,
      'username': username,
      'password': password,
    }, auth: false);
    if (res.statusCode != 201) throw Exception('Registration failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> meProfile() async {
    final res = await _api.get('/auth/me/');
    if (res.statusCode == 401) {
      final ok = await _api.refreshAccessToken();
      if (ok) return meProfile();
    }
    if (res.statusCode != 200) throw Exception('Failed to load profile');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String?> storedRole() => _api.role;

  Future<void> logout() => _api.clearSession();

  ApiClient get api => _api;
}
