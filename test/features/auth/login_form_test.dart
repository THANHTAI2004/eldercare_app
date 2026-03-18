import 'package:flutter/material.dart';
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

  testWidgets('login shows required errors when fields are empty', (
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
        child: const DevicePage(),
      ),
    );
    await tester.pump();

    final loginButtonIcon = find.byIcon(Icons.login);
    await tester.ensureVisible(loginButtonIcon);
    await tester.tap(loginButtonIcon);
    await tester.pumpAndSettle();

    expect(find.text('Nhap so dien thoai'), findsOneWidget);
    expect(find.text('Nhap mat khau'), findsOneWidget);
  });

  testWidgets('login shows invalid phone error for short number', (
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
        child: const DevicePage(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'So dien thoai'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mat khau'),
      'MatKhau123',
    );
    final loginButtonIcon = find.byIcon(Icons.login);
    await tester.ensureVisible(loginButtonIcon);
    await tester.tap(loginButtonIcon);
    await tester.pumpAndSettle();

    expect(find.text('So dien thoai khong hop le'), findsOneWidget);
  });

  testWidgets('login with valid credentials authenticates session', (
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
        child: const DevicePage(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'So dien thoai'),
      '0987654321',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mat khau'),
      'MatKhau123',
    );
    final loginButtonIcon = find.byIcon(Icons.login);
    await tester.ensureVisible(loginButtonIcon);
    await tester.tap(loginButtonIcon);
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(session.authenticatedUserId, 'user-001');
  });
}
