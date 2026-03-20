import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
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

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(
      find.text('Đăng nhập để tải danh sách thiết bị đã liên kết'),
      findsOneWidget,
    );
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('DevicePage validates login fields before submit', (
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

    final loginButtonIcon = find.byIcon(Icons.login);
    await tester.ensureVisible(loginButtonIcon);
    await tester.tap(loginButtonIcon);
    await tester.pumpAndSettle();

    expect(find.text('Nhập số điện thoại'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
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

    expect(find.text('Chưa đăng nhập'), findsOneWidget);
    expect(
      find.text(
        'Bạn cần đăng nhập trước, sau đó ứng dụng sẽ tải danh sách thiết bị đã liên kết từ máy chủ.',
      ),
      findsOneWidget,
    );
    expect(find.text('Đăng nhập'), findsOneWidget);
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

    expect(find.text('Bạn chưa có thiết bị nào'), findsOneWidget);
    expect(find.text('Mở danh sách thiết bị'), findsOneWidget);
  });

  testWidgets('DevicePage shows no-device state for authenticated user', (
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

    expect(find.text('Bạn chưa có thiết bị nào'), findsOneWidget);
    expect(find.text('Liên kết thiết bị'), findsOneWidget);
    expect(find.text('Xem huong dan lien ket'), findsOneWidget);
  });

  testWidgets('HomePage hides ECG action for viewer', (tester) async {
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

    expect(find.text('Yêu cầu đo ECG'), findsNothing);
  });

  testWidgets('RegisterPage validates required fields inline', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    final registerButtonIcon = find.byIcon(Icons.person_add_alt_1);
    await tester.ensureVisible(registerButtonIcon);
    await tester.tap(registerButtonIcon);
    await tester.pumpAndSettle();

    expect(find.text('Nhập họ và tên'), findsOneWidget);
    expect(find.text('Nhập số điện thoại'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu'), findsWidgets);
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
}
