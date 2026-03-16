import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('login stores authenticated session state', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: _MemorySecureStore());
    final provider = SessionProvider(
      client: client,
      authApi: _FakeAuthApiService(
        client: client,
        storage: storage,
        loginTokens: const AuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
        meResponse: const <String, dynamic>{
          'user_id': 'patient-001',
          'role': 'patient',
        },
      ),
    );

    final ok = await provider.login(
      userId: 'patient-001',
      password: 'secret',
    );

    expect(ok, isTrue);
    expect(provider.isAuthenticated, isTrue);
    expect(provider.authenticatedUserId, 'patient-001');
    expect(provider.authenticatedRole, 'patient');
  });

  test('restoreSession clears state when me fails', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: _MemorySecureStore());
    final provider = SessionProvider(
      client: client,
      authApi: _FakeAuthApiService(
        client: client,
        storage: storage,
        restoredTokens: const AuthTokens(
          accessToken: 'stale-access',
          refreshToken: 'refresh-token',
        ),
        meError: ApiRequestException(
          method: 'GET',
          path: '/api/v1/auth/me',
          message: 'expired',
          statusCode: 401,
        ),
      ),
    );

    final restored = await provider.restoreSession();

    expect(restored, isFalse);
    expect(provider.isAuthenticated, isFalse);
    expect(provider.authenticatedUserId, isEmpty);
  });
}

class _FakeAuthApiService extends AuthApiService {
  _FakeAuthApiService({
    required super.client,
    required super.storage,
    this.loginTokens,
    this.restoredTokens,
    this.meResponse = const <String, dynamic>{},
    this.meError,
  });

  final AuthTokens? loginTokens;
  final AuthTokens? restoredTokens;
  final Map<String, dynamic> meResponse;
  final ApiRequestException? meError;

  @override
  Future<AuthTokens> login({
    required String userId,
    required String password,
  }) async {
    if (loginTokens == null) {
      throw StateError('Missing fake login tokens');
    }
    return loginTokens!;
  }

  @override
  Future<Map<String, dynamic>> me() async {
    if (meError != null) throw meError!;
    return meResponse;
  }

  @override
  Future<AuthTokens?> restoreSessionTokens() async => restoredTokens;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearPersistedSession() async {}
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
