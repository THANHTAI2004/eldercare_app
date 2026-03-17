import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/features/auth/register_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

import '../../support/auth_widget_test_support.dart';
import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('register shows inline validation for required fields', (
    tester,
  ) async {
    final session = buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
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
    expect(find.text('Nhap mat khau'), findsOneWidget);
    expect(find.text('Nhap lai mat khau'), findsOneWidget);
  });

  testWidgets('register shows date and password mismatch errors', (
    tester,
  ) async {
    final session = buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const RegisterPage(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ho va ten'),
      'Nguyen Van A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'So dien thoai'),
      '0987654321',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mat khau'),
      'MatKhau123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nhap lai mat khau'),
      'MatKhau999',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tao tai khoan'));
    await tester.pump();

    expect(find.text('Mat khau nhap lai khong khop'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nhap lai mat khau'),
      'MatKhau123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tao tai khoan'));
    await tester.pump();

    expect(find.text('Vui long chon ngay sinh'), findsOneWidget);
  });

  testWidgets('register shows short password error', (tester) async {
    final session = buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const RegisterPage(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ho va ten'),
      'Nguyen Van A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'So dien thoai'),
      '0987654321',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mat khau'),
      '1234567',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nhap lai mat khau'),
      '1234567',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tao tai khoan'));
    await tester.pump();

    expect(find.text('Mat khau phai tu 8 ky tu tro len'), findsOneWidget);
  });

  testWidgets('register with valid form calls session register flow', (
    tester,
  ) async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final authApi = FakeAuthApiService(
      client: client,
      storage: AuthStorage(secureStore: MemorySecureStore()),
    );
    final session = SessionProvider(client: client, authApi: authApi);
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const RegisterPage(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ho va ten'),
      'Nguyen Van A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'So dien thoai'),
      '0987654321',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mat khau'),
      'MatKhau123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nhap lai mat khau'),
      'MatKhau123',
    );
    await tester.tap(find.text('Chon ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tao tai khoan'));
    await tester.pump();

    expect(authApi.registerCalls, 1);
    expect(authApi.lastRegisterRequest?.phoneNumber, '0987654321');
  });
}
