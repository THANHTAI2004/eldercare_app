import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/register_request.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

import 'test_helpers.dart';

class AuthTestShell extends StatelessWidget {
  const AuthTestShell({
    super.key,
    required this.session,
    required this.deviceProvider,
    required this.child,
  });

  final SessionProvider session;
  final DeviceProvider deviceProvider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final healthApi = FakeHealthApiService();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ChangeNotifierProvider<RealtimeProvider>(
          create: (_) => RealtimeProvider(
            client: client,
            api: healthApi,
          )..handleSessionState(
            isAuthenticated: session.isAuthenticated,
            authenticatedUserId: session.authenticatedUserId,
            ),
        ),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => HistoryProvider(
            client: client,
            api: healthApi,
          )..handleSessionState(
            isAuthenticated: session.isAuthenticated,
            authenticatedUserId: session.authenticatedUserId,
            ),
        ),
        ChangeNotifierProvider<EcgProvider>(
          create: (_) => EcgProvider(
            client: client,
            api: healthApi,
          )..handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
            ),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }
}

SessionProvider buildSessionProvider({
  FakeAuthApiService? authApi,
  AuthTokens? loginTokens,
  Map<String, dynamic> meResponse = const <String, dynamic>{},
}) {
  final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
  final resolvedAuthApi =
      authApi ??
      FakeAuthApiService(
        client: client,
        storage: AuthStorage(secureStore: MemorySecureStore()),
        loginTokens: loginTokens,
        meResponse: meResponse,
      );
  return SessionProvider(
    client: client,
    authApi: resolvedAuthApi,
  );
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService({
    required super.client,
    required super.storage,
    this.loginTokens,
    this.meResponse = const <String, dynamic>{},
    this.registerError,
  });

  final AuthTokens? loginTokens;
  final Map<String, dynamic> meResponse;
  final Object? registerError;

  int loginCalls = 0;
  int registerCalls = 0;
  String? lastLoginPhoneNumber;
  String? lastLoginPassword;
  RegisterRequest? lastRegisterRequest;

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
    registerCalls += 1;
    lastRegisterRequest = request;
    if (registerError != null) {
      throw registerError!;
    }
  }

  @override
  Future<Map<String, dynamic>> me() async => meResponse;

  @override
  Future<AuthTokens?> restoreSessionTokens() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearPersistedSession() async {}
}

class FakeDeviceApiService extends DeviceApiService {
  FakeDeviceApiService({required this.devices})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<Device> devices;

  @override
  Future<List<Device>> getMyDevices() async => devices;
}

class FakeHealthApiService extends HealthApiService {
  FakeHealthApiService()
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  @override
  Future<VitalPoint> getLatestByDevice({required String deviceId}) async {
    throw ApiRequestException(
      method: 'GET',
      path: '/api/v1/devices/$deviceId/latest',
      message: 'No data found',
      statusCode: 404,
    );
  }

  @override
  Future<List<VitalPoint>> getHistoryByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    return const <VitalPoint>[];
  }
}
