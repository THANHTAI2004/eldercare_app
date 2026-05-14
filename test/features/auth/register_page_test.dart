import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/core/app_strings.dart';
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
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Nhập họ và tên'), findsWidgets);
    expect(find.text(AppStrings.loginPhoneRequired), findsWidgets);
    expect(find.text(AppStrings.loginPasswordRequired), findsWidgets);
    expect(find.text('Nhập lại mật khẩu'), findsWidgets);
  });

  testWidgets('register shows date and password mismatch errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyen Van A');
    await tester.enterText(find.byType(TextFormField).at(1), '0987654321');
    await tester.enterText(find.byType(TextFormField).at(2), 'MatKhau123');
    await tester.enterText(find.byType(TextFormField).at(3), 'MatKhau999');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), 'MatKhau123');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.registerPickBirthDate), findsOneWidget);
  });

  testWidgets('register shows short password error', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyen Van A');
    await tester.enterText(find.byType(TextFormField).at(1), '0987654321');
    await tester.enterText(find.byType(TextFormField).at(2), '1234567');
    await tester.enterText(find.byType(TextFormField).at(3), '1234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.passwordTooShort), findsOneWidget);
  });

  testWidgets('register with valid form calls session register flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyen Van A');
    await tester.enterText(find.byType(TextFormField).at(1), '0987654321');
    await tester.enterText(find.byType(TextFormField).at(2), 'MatKhau123');
    await tester.enterText(find.byType(TextFormField).at(3), 'MatKhau123');

    await tester.tap(find.widgetWithText(TextButton, 'Chọn ngày'));
    await tester.pumpAndSettle();

    final confirmDateButton = find.text('OK').evaluate().isNotEmpty
        ? find.text('OK').last
        : find.text('Save').last;
    await tester.tap(confirmDateButton);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(authApi.registerCalls, 1);
    expect(authApi.lastRegisterRequest?.phoneNumber, '+84987654321');
  });
}
