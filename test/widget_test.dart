import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/alerts_api_service.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/alert_item.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/features/home/home_page.dart';
import 'package:eldercare_app/src/features/navigation/app_root_page.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

import 'support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('AppRootPage shows login page when session is unauthenticated', (
    tester,
  ) async {
    final session = _buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(devices: const <Device>[]),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      _TestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const AppRootPage(),
      ),
    );
    await tester.pump();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets('HomePage shows no-device state for authenticated user', (
    tester,
  ) async {
    final session = _buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'user-001',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987654321', password: 'secret');

    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(devices: const <Device>[]),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      _TestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const HomePage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bạn chưa chọn thiết bị theo dõi'), findsOneWidget);
    expect(find.text('Mở màn thiết bị'), findsOneWidget);
  });

  testWidgets('DevicePage shows redesigned empty state for authenticated user', (
    tester,
  ) async {
    final session = _buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'user-001',
        'name': 'Nguyen Van A',
        'phone_number': '0987654321',
        'date_of_birth': '1950-01-02',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987654321', password: 'secret');

    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(devices: const <Device>[]),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      _TestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const DevicePage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bạn chưa liên kết thiết bị nào'), findsOneWidget);
    expect(find.text('Liên kết thiết bị'), findsWidgets);
  });

  testWidgets('HomePage keeps ECG quick action visible for viewer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final session = _buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'viewer-001',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987000001', password: 'secret');

    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson(const <String, dynamic>{
            'device_id': 'dev-1',
            'name': 'Phong ngu',
            'link_role': 'viewer',
            'linked_users': <Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'owner-001',
                'name': 'Owner A',
                'link_role': 'owner',
              },
              <String, dynamic>{
                'user_id': 'viewer-001',
                'name': 'Viewer A',
                'link_role': 'viewer',
              },
            ],
          }),
        ],
      ),
    );
    await deviceProvider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: session.authenticatedUserId,
    );

    await tester.pumpWidget(
      _TestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const HomePage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('ECG'), findsWidgets);
  });
}

class _TestShell extends StatelessWidget {
  const _TestShell({
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
    final healthApi = _FakeHealthApiService();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ChangeNotifierProvider<RealtimeProvider>(
          create: (_) =>
              RealtimeProvider(
                client: client,
                api: healthApi,
              )..handleSessionState(
                isAuthenticated: session.isAuthenticated,
                authenticatedUserId: session.authenticatedUserId,
              ),
        ),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) =>
              HistoryProvider(
                client: client,
                api: healthApi,
              )..handleSessionState(
                isAuthenticated: session.isAuthenticated,
                authenticatedUserId: session.authenticatedUserId,
              ),
        ),
        ChangeNotifierProvider<EcgProvider>(
          create: (_) =>
              EcgProvider(client: client, api: healthApi)..handleSessionState(
                isAuthenticated: session.isAuthenticated,
                authenticatedUserId: session.authenticatedUserId,
              ),
        ),
        ChangeNotifierProvider<AlertsProvider>(
          create: (_) =>
              AlertsProvider(
                api: _FakeAlertsApiService(client: client),
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

SessionProvider _buildSessionProvider({
  AuthTokens? loginTokens,
  Map<String, dynamic> meResponse = const <String, dynamic>{},
}) {
  final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
  return SessionProvider(
    client: client,
    authApi: _FakeAuthApiService(
      client: client,
      storage: AuthStorage(secureStore: MemorySecureStore()),
      loginTokens: loginTokens,
      meResponse: meResponse,
    ),
  );
}

class _FakeAuthApiService extends AuthApiService {
  _FakeAuthApiService({
    required super.client,
    required super.storage,
    this.loginTokens,
    this.meResponse = const <String, dynamic>{},
  });

  final AuthTokens? loginTokens;
  final Map<String, dynamic> meResponse;

  @override
  Future<AuthTokens> login({
    required String phoneNumber,
    required String password,
  }) async {
    if (loginTokens == null) {
      throw StateError('Missing fake login tokens');
    }
    return loginTokens!;
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

class _FakeDeviceApiService extends DeviceApiService {
  _FakeDeviceApiService({required this.devices})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<Device> devices;

  @override
  Future<List<Device>> getMyDevices() async => devices;
}

class _FakeHealthApiService extends HealthApiService {
  _FakeHealthApiService()
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

  @override
  Future<EcgReading?> getLatestEcgByDevice({
    required String deviceId,
    int limit = 1,
  }) async {
    return EcgReading(
      recordedAt: DateTime.parse('2026-03-24T10:46:07.177Z'),
      waveform: const <double>[0.12, 0.18, 0.05, -0.03, 0.22],
      samplingRate: 250,
      quality: 'good',
      leadOff: false,
    );
  }

  @override
  Future<List<EcgReading>> getEcgReadingsByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    return const <EcgReading>[];
  }
}

class _FakeAlertsApiService extends AlertsApiService {
  _FakeAlertsApiService({required super.client});

  @override
  Future<List<AlertItem>> getAlertsByDevice({required String deviceId}) async {
    return const <AlertItem>[];
  }
}
