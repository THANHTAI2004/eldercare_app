import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/register_request.dart';

import 'support/test_helpers.dart';

void main() {
  setUp(() {
    setUpSharedPreferences();
  });

  test('login stores access and refresh tokens', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final storage = AuthStorage(secureStore: MemorySecureStore());
    final api = AuthApiService(client: client, storage: storage);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/auth/login');
        expect(options.data, <String, dynamic>{
          'phone_number': '0987654321',
          'password': 'secret',
        });
        return jsonResponse(<String, dynamic>{
          'access_token': 'access-123',
          'refresh_token': 'refresh-456',
        }, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;

    final tokens = await api.login(
      phoneNumber: '0987654321',
      password: 'secret',
    );

    expect(tokens.accessToken, 'access-123');
    expect(tokens.refreshToken, 'refresh-456');
    expect(client.accessToken, 'access-123');
    expect(await storage.loadAccessToken(), 'access-123');
    expect(await storage.loadRefreshToken(), 'refresh-456');
  });

  test('restoreSessionTokens rehydrates client access token', () async {
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final api = AuthApiService(client: client, storage: storage);

    await storage.saveAccessToken('restored-access');
    await storage.saveRefreshToken('restored-refresh');

    final tokens = await api.restoreSessionTokens();

    expect(tokens?.accessToken, 'restored-access');
    expect(tokens?.refreshToken, 'restored-refresh');
    expect(client.accessToken, 'restored-access');
  });

  test('refreshSession replaces tokens using refresh_token payload', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    final api = AuthApiService(client: client, storage: storage);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/auth/refresh');
        expect(options.data, <String, dynamic>{'refresh_token': 'refresh-456'});
        return jsonResponse(<String, dynamic>{
          'access_token': 'fresh-access',
          'refresh_token': 'fresh-refresh',
        }, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;

    final tokens = await api.refreshSession(refreshToken: 'refresh-456');

    expect(tokens.accessToken, 'fresh-access');
    expect(tokens.refreshToken, 'fresh-refresh');
    expect(client.accessToken, 'fresh-access');
    expect(await storage.loadAccessToken(), 'fresh-access');
    expect(await storage.loadRefreshToken(), 'fresh-refresh');
  });

  test('register sends the expected payload to the backend', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final api = AuthApiService(
      client: client,
      storage: AuthStorage(secureStore: MemorySecureStore()),
    );
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/auth/register');
        expect(options.data, <String, dynamic>{
          'name': 'Nguyen Van A',
          'phone_number': '0987654321',
          'date_of_birth': '1950-01-02',
          'password': 'MatKhau123',
        });
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;

    await api.register(
      const RegisterRequest(
        name: 'Nguyen Van A',
        phoneNumber: '0987654321',
        dateOfBirth: '1950-01-02',
        password: 'MatKhau123',
      ),
    );
  });

  test('logout calls server with bearer token and clears persisted session', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    final api = AuthApiService(client: client, storage: storage);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/auth/logout');
        expect(options.headers['Authorization'], 'Bearer access-123');
        expect(options.data, isNull);
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;
    client.setAccessToken('access-123');
    await storage.saveAccessToken('access-123');
    await storage.saveRefreshToken('refresh-456');
    await storage.saveCurrentUser(<String, dynamic>{'user_id': 'user-001'});

    await api.logout();

    expect(client.accessToken, isNull);
    expect(await storage.loadAccessToken(), isNull);
    expect(await storage.loadRefreshToken(), isNull);
    expect(await storage.loadCurrentUser(), isNull);
  });
}
