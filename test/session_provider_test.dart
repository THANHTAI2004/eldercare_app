import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/register_request.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

import 'support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  test('bootstrap without saved tokens stays unauthenticated', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final authApi = _FakeAuthApiService(
      client: client,
      storage: AuthStorage(secureStore: MemorySecureStore()),
    );
    final provider = SessionProvider(client: client, authApi: authApi);

    await provider.bootstrap();

    expect(authApi.restoreCalls, 1);
    expect(provider.isAuthenticated, isFalse);
    expect(provider.currentUser, isNull);
    expect(provider.isBootstrapping, isFalse);
  });

  test('login stores authenticated session state', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: MemorySecureStore());
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
          'user_id': 'user-001',
          'role': 'member',
        },
      ),
    );

    final ok = await provider.login(
      phoneNumber: '0987654321',
      password: 'secret',
    );

    expect(ok, isTrue);
    expect(provider.isAuthenticated, isTrue);
    expect(provider.authenticatedUserId, 'user-001');
    expect(provider.authenticatedRole, 'member');
  });

  test('login normalizes whitespace inside phone number before calling API', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: MemorySecureStore());
    final authApi = _FakeAuthApiService(
      client: client,
      storage: storage,
      loginTokens: const AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'user-001',
        'role': 'member',
      },
    );
    final provider = SessionProvider(client: client, authApi: authApi);

    final ok = await provider.login(
      phoneNumber: '0987 654 321',
      password: 'secret',
    );

    expect(ok, isTrue);
    expect(authApi.lastLoginPhoneNumber, '0987654321');
    expect(authApi.lastLoginPassword, 'secret');
  });

  test('register normalizes whitespace inside phone number before calling API', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: MemorySecureStore());
    final authApi = _FakeAuthApiService(
      client: client,
      storage: storage,
    );
    final provider = SessionProvider(client: client, authApi: authApi);

    final ok = await provider.register(
      name: 'Nguyen Van A',
      phoneNumber: '0987 654 321',
      dateOfBirth: '1950-01-02',
      password: 'MatKhau123',
    );

    expect(ok, isTrue);
    expect(authApi.lastRegisterRequest, isNotNull);
    expect(authApi.lastRegisterRequest!.phoneNumber, '0987654321');
  });

  test(
    'restoreSession loads current user and marks provider authenticated',
    () async {
      final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
      final storage = AuthStorage(secureStore: MemorySecureStore());
      final authApi = _FakeAuthApiService(
        client: client,
        storage: storage,
        restoredTokens: const AuthTokens(
          accessToken: 'restored-access',
          refreshToken: 'restored-refresh',
        ),
        meResponse: const <String, dynamic>{
          'user_id': 'user-001',
          'role': 'member',
        },
      );
      final provider = SessionProvider(client: client, authApi: authApi);

      final restored = await provider.restoreSession();

      expect(restored, isTrue);
      expect(authApi.restoreCalls, 1);
      expect(authApi.meCalls, 1);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.authenticatedUserId, 'user-001');
      expect(provider.authenticatedRole, 'member');
    },
  );

  test('restoreSession clears state when me fails', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: MemorySecureStore());
    final authApi = _FakeAuthApiService(
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
    );
    final provider = SessionProvider(client: client, authApi: authApi);

    final restored = await provider.restoreSession();

    expect(restored, isFalse);
    expect(provider.isAuthenticated, isFalse);
    expect(provider.authenticatedUserId, isEmpty);
    expect(
      provider.error,
      'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
    );
    expect(provider.lastErrorStatusCode, 401);
    expect(authApi.clearCalls, 1);
  });

  test('401 refreshes token and retries request successfully', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    final authApi = AuthApiService(client: client, storage: storage);
    final provider = SessionProvider(client: client, authApi: authApi);
    var secureCalls = 0;

    await storage.saveAccessToken('stale-access');
    await storage.saveRefreshToken('refresh-456');
    await storage.saveCurrentUser(<String, dynamic>{
      'user_id': 'user-001',
      'role': 'member',
    });

    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        switch (options.path) {
          case '/api/v1/auth/me':
            expect(options.headers['Authorization'], 'Bearer stale-access');
            return jsonResponse(<String, dynamic>{
              'user_id': 'user-001',
              'role': 'member',
            }, 200);
          case '/secure':
            secureCalls += 1;
            if (secureCalls == 1) {
              expect(options.headers['Authorization'], 'Bearer stale-access');
              return jsonResponse(<String, dynamic>{'detail': 'expired'}, 401);
            }
            expect(options.headers['Authorization'], 'Bearer fresh-access');
            return jsonResponse(<String, dynamic>{'ok': true}, 200);
          case '/api/v1/auth/refresh':
            expect(options.headers['Authorization'], isNull);
            expect(options.data, <String, dynamic>{
              'refresh_token': 'refresh-456',
            });
            return jsonResponse(<String, dynamic>{
              'access_token': 'fresh-access',
              'refresh_token': 'fresh-refresh',
            }, 200);
        }
        fail('Unexpected request: ${options.method} ${options.path}');
      },
    );

    final restored = await provider.restoreSession();
    final json = await client.getJson('/secure');

    expect(restored, isTrue);
    expect(json['ok'], true);
    expect(secureCalls, 2);
    expect(provider.isAuthenticated, isTrue);
    expect(provider.accessToken, 'fresh-access');
    expect(provider.refreshToken, 'fresh-refresh');
    expect(await storage.loadAccessToken(), 'fresh-access');
    expect(await storage.loadRefreshToken(), 'fresh-refresh');
  });

  test('refresh failure clears session after 401', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    final authApi = AuthApiService(client: client, storage: storage);
    final provider = SessionProvider(client: client, authApi: authApi);

    await storage.saveAccessToken('stale-access');
    await storage.saveRefreshToken('refresh-456');
    await storage.saveCurrentUser(<String, dynamic>{
      'user_id': 'user-001',
      'role': 'member',
    });

    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        switch (options.path) {
          case '/api/v1/auth/me':
            return jsonResponse(<String, dynamic>{
              'user_id': 'user-001',
              'role': 'member',
            }, 200);
          case '/secure':
            return jsonResponse(<String, dynamic>{'detail': 'expired'}, 401);
          case '/api/v1/auth/refresh':
            expect(options.data, <String, dynamic>{
              'refresh_token': 'refresh-456',
            });
            return jsonResponse(<String, dynamic>{'detail': 'expired'}, 401);
        }
        fail('Unexpected request: ${options.method} ${options.path}');
      },
    );

    final restored = await provider.restoreSession();

    expect(restored, isTrue);
    await expectLater(
      client.getJson('/secure'),
      throwsA(isA<ApiRequestException>()),
    );

    expect(provider.isAuthenticated, isFalse);
    expect(provider.currentUser, isNull);
    expect(provider.accessToken, isNull);
    expect(provider.refreshToken, isNull);
    expect(await storage.loadAccessToken(), isNull);
    expect(await storage.loadRefreshToken(), isNull);
    expect(await storage.loadCurrentUser(), isNull);
  });

  test('logout clears provider state and persisted tokens', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    final authApi = AuthApiService(client: client, storage: storage);
    final provider = SessionProvider(client: client, authApi: authApi);

    await storage.saveAccessToken('access-123');
    await storage.saveRefreshToken('refresh-456');
    await storage.saveCurrentUser(<String, dynamic>{
      'user_id': 'user-001',
      'role': 'member',
    });

    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        switch (options.path) {
          case '/api/v1/auth/me':
            return jsonResponse(<String, dynamic>{
              'user_id': 'user-001',
              'role': 'member',
            }, 200);
          case '/api/v1/auth/logout':
            expect(options.headers['Authorization'], 'Bearer access-123');
            return jsonResponse(<String, dynamic>{'ok': true}, 200);
        }
        fail('Unexpected request: ${options.method} ${options.path}');
      },
    );

    final restored = await provider.restoreSession();
    expect(restored, isTrue);

    await provider.logout();

    expect(provider.isAuthenticated, isFalse);
    expect(provider.currentUser, isNull);
    expect(provider.error, isNull);
    expect(await storage.loadAccessToken(), isNull);
    expect(await storage.loadRefreshToken(), isNull);
    expect(await storage.loadCurrentUser(), isNull);
  });
}

class _FakeAuthApiService extends AuthApiService {
  _FakeAuthApiService({
    required super.client,
    required super.storage,
    this.loginTokens,
    this.restoredTokens,
    this.savedCurrentUser,
    this.meResponse = const <String, dynamic>{},
    this.meError,
  });

  final AuthTokens? loginTokens;
  final AuthTokens? restoredTokens;
  final Map<String, dynamic>? savedCurrentUser;
  final Map<String, dynamic> meResponse;
  final ApiRequestException? meError;
  String? lastLoginPhoneNumber;
  String? lastLoginPassword;
  RegisterRequest? lastRegisterRequest;

  int loginCalls = 0;
  int restoreCalls = 0;
  int meCalls = 0;
  int logoutCalls = 0;
  int clearCalls = 0;

  @override
  Future<AuthTokens> login({
    required String phoneNumber,
    required String password,
  }) async {
    loginCalls += 1;
    lastLoginPhoneNumber = phoneNumber;
    lastLoginPassword = password;
    if (loginTokens == null) {
      throw StateError('Missing fake login tokens');
    }
    return loginTokens!;
  }

  @override
  Future<void> register(RegisterRequest request) async {
    lastRegisterRequest = request;
  }

  @override
  Future<Map<String, dynamic>> me() async {
    meCalls += 1;
    if (meError != null) throw meError!;
    return meResponse;
  }

  @override
  Future<AuthTokens?> restoreSessionTokens() async {
    restoreCalls += 1;
    return restoredTokens;
  }

  @override
  Future<Map<String, dynamic>?> loadSavedCurrentUser() async {
    return savedCurrentUser;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }

  @override
  Future<void> clearPersistedSession() async {
    clearCalls += 1;
  }
}
