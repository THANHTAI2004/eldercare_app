import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/register_request.dart';

class AuthApiService {
  AuthApiService({required ApiClient client, AuthStorage? storage})
    : _client = client,
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<AuthTokens> login({
    required String phoneNumber,
    required String password,
  }) async {
    final json = await _client.postJson(
      '/api/v1/auth/login',
      data: <String, dynamic>{
        'phone_number': phoneNumber,
        'password': password,
      },
      extra: const <String, dynamic>{
        ApiClient.skipAuthRefreshKey: true,
        ApiClient.omitAccessTokenKey: true,
      },
    );

    final tokens = AuthTokens.fromJson(json);
    if (tokens.accessToken.isEmpty) {
      throw StateError('Login response did not include access token');
    }

    await saveTokens(tokens);
    return tokens;
  }

  Future<void> register(RegisterRequest request) async {
    await _client.postJson(
      '/api/v1/auth/register',
      data: request.toJson(),
      extra: const <String, dynamic>{
        ApiClient.skipAuthRefreshKey: true,
        ApiClient.omitAccessTokenKey: true,
      },
    );
  }

  Future<Map<String, dynamic>> me() async {
    final json = await _client.getJson('/api/v1/auth/me');
    await _storage.saveCurrentUser(json);
    return json;
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String dateOfBirth,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'date_of_birth': dateOfBirth.trim(),
    };

    final updated = await _client.patchJson('/api/v1/auth/me', data: payload);
    await _storage.saveCurrentUser(updated);
    return updated;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final payload = <String, dynamic>{
      'current_password': currentPassword,
      'new_password': newPassword,
    };

    await _client.postJson('/api/v1/auth/change-password', data: payload);
  }

  Future<AuthTokens?> restoreSessionTokens() async {
    final accessToken = await _storage.loadAccessToken();
    final refreshToken = await _storage.loadRefreshToken();
    _client.setAccessToken(accessToken);

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken ?? '',
    );
  }

  Future<Map<String, dynamic>?> loadSavedCurrentUser() {
    return _storage.loadCurrentUser();
  }

  Future<AuthTokens> refreshSession({required String refreshToken}) async {
    final json = await _client.postJson(
      '/api/v1/auth/refresh',
      data: <String, dynamic>{'refresh_token': refreshToken},
      extra: const <String, dynamic>{
        ApiClient.skipAuthRefreshKey: true,
        ApiClient.omitAccessTokenKey: true,
      },
    );

    final nextTokens = AuthTokens.fromJson({
      ...json,
      if ((json['refresh_token']?.toString().trim().isEmpty ?? true))
        'refresh_token': refreshToken,
    });
    if (nextTokens.accessToken.isEmpty) {
      throw StateError('Refresh response did not include access token');
    }

    await saveTokens(nextTokens);
    return nextTokens;
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    _client.setAccessToken(tokens.accessToken);
    await _storage.saveAccessToken(tokens.accessToken);
    if (tokens.refreshToken.trim().isNotEmpty) {
      await _storage.saveRefreshToken(tokens.refreshToken);
    } else {
      await _storage.clearRefreshToken();
    }
  }

  Future<void> saveCurrentUser(Map<String, dynamic> user) {
    return _storage.saveCurrentUser(user);
  }

  Future<void> clearPersistedSession() async {
    _client.clearAccessToken();
    await _storage.clear();
  }

  Future<void> logout() async {
    try {
      await _client.postJson(
        '/api/v1/auth/logout',
        extra: const <String, dynamic>{ApiClient.skipAuthRefreshKey: true},
      );
    } catch (_) {}
    await clearPersistedSession();
  }
}
