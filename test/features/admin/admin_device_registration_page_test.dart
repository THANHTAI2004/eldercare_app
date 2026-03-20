import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/device_registration_result.dart';
import 'package:eldercare_app/src/features/admin/admin_device_registration_page.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

import '../../support/auth_widget_test_support.dart';
import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('non-admin sees access denied on admin registration page', (
    tester,
  ) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'member-001',
        'name': 'Member A',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987000001', password: 'MatKhau123');

    await tester.pumpWidget(
      _AdminPageShell(
        session: session,
        child: AdminDeviceRegistrationPage(api: _FakeAdminDeviceApiService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trang này chỉ dành cho quản trị viên'), findsOneWidget);
    expect(find.text('Đăng ký thiết bị cho quản trị viên'), findsNothing);
  });

  testWidgets('admin can register device and receive pairing code', (
    tester,
  ) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'admin-001',
        'name': 'Admin A',
        'role': 'admin',
      },
    );
    await session.login(phoneNumber: '0987000002', password: 'MatKhau123');

    final api = _FakeAdminDeviceApiService();

    await tester.pumpWidget(
      _AdminPageShell(
        session: session,
        child: AdminDeviceRegistrationPage(api: api),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dev-esp-001');
    await tester.enterText(find.byType(TextFormField).at(1), 'Máy đo phòng ngủ');
    await tester.enterText(find.byType(TextFormField).at(2), 'esp32');
    await tester.enterText(find.byType(TextFormField).at(3), '1.0.0');
    await tester.enterText(find.byType(TextFormField).at(4), 'PAIR-001');
    await tester.tap(find.text('Đăng ký thiết bị'));
    await tester.pumpAndSettle();

    expect(api.lastDeviceId, 'dev-esp-001');
    expect(api.lastDeviceName, 'Máy đo phòng ngủ');
    expect(api.lastDeviceType, 'esp32');
    expect(api.lastFirmwareVersion, '1.0.0');
    expect(api.lastPairingCode, 'PAIR-001');
    expect(find.text('Đăng ký thiết bị thành công'), findsOneWidget);
    expect(find.textContaining('Mã ghép nối: PAIR-001'), findsOneWidget);
  });
}

class _AdminPageShell extends StatelessWidget {
  const _AdminPageShell({
    required this.session,
    required this.child,
  });

  final SessionProvider session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(
          value: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
        ),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
      ],
      child: MaterialApp(home: child),
    );
  }
}

class _FakeAdminDeviceApiService extends DeviceApiService {
  _FakeAdminDeviceApiService()
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  String? lastDeviceId;
  String? lastDeviceName;
  String? lastDeviceType;
  String? lastFirmwareVersion;
  String? lastPairingCode;

  @override
  Future<DeviceRegistrationResult> registerDevice({
    required String deviceId,
    String? deviceName,
    String? deviceType,
    String? firmwareVersion,
    String? pairingCode,
  }) async {
    lastDeviceId = deviceId;
    lastDeviceName = deviceName;
    lastDeviceType = deviceType;
    lastFirmwareVersion = firmwareVersion;
    lastPairingCode = pairingCode;

    return const DeviceRegistrationResult(
      status: 'success',
      deviceId: 'dev-esp-001',
      pairingCode: 'PAIR-001',
    );
  }
}
