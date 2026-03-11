import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';

class AuthApiService {
  AuthApiService({required ApiClient client, AuthStorage? storage})
    : _client = client,
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    final json = await _client.postJson(
      '/api/v1/auth/login',
      data: <String, dynamic>{'user_id': userId, 'password': password},
    );

    final token = json['access_token']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Login response did not include access_token');
    }

    await setAccessToken(token);
    return json;
  }

  Future<Map<String, dynamic>> me() async {
    final json = await _client.getJson('/api/v1/auth/me');
    await _storage.saveCurrentUser(json);
    return json;
  }

  Future<String?> restoreAccessToken() async {
    final token = await _storage.loadAccessToken();
    _client.setAccessToken(token);
    return token;
  }

  Future<Map<String, dynamic>?> loadSavedCurrentUser() {
    return _storage.loadCurrentUser();
  }

  Future<void> setAccessToken(String? token) async {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await clearAccessToken();
      return;
    }

    _client.setAccessToken(trimmed);
    await _storage.saveAccessToken(trimmed);
  }

  Future<void> saveCurrentUser(Map<String, dynamic> user) {
    return _storage.saveCurrentUser(user);
  }

  Future<void> clearAccessToken() async {
    _client.clearAccessToken();
    await _storage.clear();
  }

  Future<void> logout() {
    return clearAccessToken();
  }
}
