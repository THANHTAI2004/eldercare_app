import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/data/local/vitals_cache_storage.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/features/auth/register_page.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/features/home/home_page.dart';
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

  testWidgets('DevicePage shows login form when session is unauthenticated', (
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
        child: const DevicePage(),
      ),
    );
    await tester.pump();

    expect(find.text('Dang nhap'), findsWidgets);
    expect(
      find.text('Dang nhap de tai danh sach thiet bi da lien ket'),
      findsOneWidget,
    );
    expect(find.text('So dien thoai'), findsOneWidget);
    expect(find.text('Mat khau'), findsOneWidget);
    expect(find.text('Chua co tai khoan? Dang ky'), findsOneWidget);
  });

  testWidgets('DevicePage validates login fields before submit', (tester) async {
    final session = _buildSessionProvider();
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

    await tester.tap(find.widgetWithText(FilledButton, 'Dang nhap'));
    await tester.pump();

    expect(find.text('Nhap so dien thoai'), findsOneWidget);
    expect(find.text('Nhap mat khau'), findsOneWidget);
  });

  testWidgets('HomePage shows unauthenticated empty state with no device', (
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
        child: const HomePage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Chua dang nhap'), findsOneWidget);
    expect(
      find.text(
        'Ban can dang nhap truoc, sau do app se tai danh sach device da lien ket tu server.',
      ),
      findsOneWidget,
    );
    expect(find.text('Dang nhap'), findsOneWidget);
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
        'user_id': 'patient-001',
        'role': 'manager',
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

    expect(find.text('Ban chua co thiet bi nao'), findsOneWidget);
    expect(find.text('Quan ly thiet bi'), findsOneWidget);
  });

  testWidgets('DevicePage shows manager no-device state', (
    tester,
  ) async {
    final session = _buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'patient-001',
        'name': 'Nguyen Van A',
        'phone_number': '0987654321',
        'date_of_birth': '1950-01-02',
        'role': 'manager',
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

    expect(find.text('Ban chua co thiet bi nao'), findsOneWidget);
    expect(find.text('Them thiet bi bang device_id'), findsOneWidget);
    expect(find.text('Xem huong dan lien ket'), findsOneWidget);
  });

  testWidgets('HomePage hides ECG action for caregiver', (tester) async {
    final session = _buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'caregiver-001',
        'role': 'caregiver',
      },
    );
    await session.login(phoneNumber: '0987000001', password: 'secret');

    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson(const <String, dynamic>{
            'device_id': 'dev-1',
            'name': 'Phong ngu',
            'link_role': 'caregiver',
            'linked_users': <Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'manager-001',
                'name': 'Manager A',
                'role': 'manager',
                'link_role': 'owner',
              },
              <String, dynamic>{
                'user_id': 'caregiver-001',
                'name': 'Caregiver A',
                'role': 'caregiver',
                'link_role': 'caregiver',
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

    expect(find.text('Yeu cau ECG'), findsNothing);
  });

  testWidgets('RegisterPage validates required fields inline', (tester) async {
    final session = _buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(devices: const <Device>[]),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      _TestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const RegisterPage(),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Tao tai khoan'));
    await tester.pump();

    expect(find.text('Nhap ho va ten'), findsOneWidget);
    expect(find.text('Nhap so dien thoai'), findsOneWidget);
    expect(find.text('Vui long chon ngay sinh'), findsOneWidget);
    expect(find.text('Nhap mat khau'), findsOneWidget);
    expect(find.text('Nhap lai mat khau'), findsOneWidget);
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
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ChangeNotifierProvider<RealtimeProvider>(
          create: (_) => RealtimeProvider(
            client: client,
            api: healthApi,
            cacheStorage: VitalsCacheStorage(),
          )..handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
              authenticatedRole: session.authenticatedRole,
            ),
        ),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => HistoryProvider(
            client: client,
            api: healthApi,
            cacheStorage: VitalsCacheStorage(),
          )..handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
              authenticatedRole: session.authenticatedRole,
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
  Future<VitalPoint> getLatestByUser({
    required String userId,
    String? deviceId,
  }) async {
    throw ApiRequestException(
      method: 'GET',
      path: '/api/v1/users/$userId/latest',
      message: 'No data found',
      statusCode: 404,
    );
  }

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
  Future<List<VitalPoint>> getVitalsByUser({
    required String userId,
    String? deviceId,
    int limit = 100,
  }) async {
    return const <VitalPoint>[];
  }

  @override
  Future<List<VitalPoint>> getHistoryByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    return const <VitalPoint>[];
  }
}
