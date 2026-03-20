import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

import '../../support/auth_widget_test_support.dart';
import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('authenticated user with no devices sees claim device CTA', (
    tester,
  ) async {
    final session = buildSessionProvider(
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
    await session.login(phoneNumber: '0987654321', password: 'MatKhau123');

    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const DevicePage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bạn chưa có thiết bị nào'), findsOneWidget);
    expect(find.text('Liên kết thiết bị'), findsOneWidget);
    expect(find.text('Xem hướng dẫn liên kết'), findsOneWidget);
  });

  testWidgets('viewer account with no devices sees shared guidance', (
    tester,
  ) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'viewer-001',
        'name': 'Viewer A',
        'phone_number': '0987000001',
        'date_of_birth': '1988-05-06',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987000001', password: 'MatKhau123');

    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const DevicePage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bạn chưa có thiết bị nào'), findsOneWidget);
    expect(find.text('Liên kết thiết bị'), findsOneWidget);
    expect(find.text('Xem hướng dẫn liên kết'), findsOneWidget);
  });
}
