import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/features/auth/login_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

import '../../support/auth_widget_test_support.dart';
import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('login shows required errors when fields are empty', (
    tester,
  ) async {
    _setLargeView(tester);
    final session = buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const LoginPage(),
      ),
    );
    await tester.pump();

    final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginPhoneRequired), findsWidgets);
    expect(find.text(AppStrings.loginPasswordRequired), findsWidgets);
  });

  testWidgets('login shows invalid phone error for short number', (
    tester,
  ) async {
    _setLargeView(tester);
    final session = buildSessionProvider();
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const LoginPage(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), '123');
    await tester.enterText(find.byType(TextFormField).at(1), 'MatKhau123');
    final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.phoneInvalid), findsOneWidget);
  });

  testWidgets('login with valid credentials authenticates session', (
    tester,
  ) async {
    _setLargeView(tester);
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'user-001',
        'name': 'Nguyen Van A',
        'phone_number': '0987654321',
        'role': 'member',
      },
    );
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const LoginPage(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), '0987654321');
    await tester.enterText(find.byType(TextFormField).at(1), 'MatKhau123');
    final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(session.authenticatedUserId, 'user-001');
  });

  testWidgets('login strips spaces inside phone number before submit', (
    tester,
  ) async {
    _setLargeView(tester);
    final authApi = FakeAuthApiService(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      storage: AuthStorage(secureStore: MemorySecureStore()),
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'user-001',
        'name': 'Nguyen Van A',
        'phone_number': '0987654321',
        'role': 'member',
      },
    );
    final session = buildSessionProvider(authApi: authApi);
    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(devices: const []),
    );
    await deviceProvider.load();

    await tester.pumpWidget(
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const LoginPage(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), '0987 654 321');
    await tester.enterText(find.byType(TextFormField).at(1), 'MatKhau123');
    final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(authApi.lastLoginPhoneNumber, '+84987654321');
    expect(authApi.lastLoginPassword, 'MatKhau123');
  });
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
