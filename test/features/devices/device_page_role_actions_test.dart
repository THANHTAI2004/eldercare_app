import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

import '../../support/auth_widget_test_support.dart';
import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('owner sees viewer management action on device page', (
    tester,
  ) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'owner-001',
        'name': 'Owner A',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987654321', password: 'MatKhau123');

    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson(const <String, dynamic>{
            'device_id': 'dev-esp-001',
            'name': 'Phong ngu',
            'user_id': 'owner-001',
            'link_role': 'owner',
            'linked_users': <Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'owner-001',
                'name': 'Owner A',
                'link_role': 'owner',
              },
              <String, dynamic>{
                'user_id': 'viewer-001',
                'name': 'Nguoi nha',
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
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const DevicePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản lý'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Quản lý'));
    await tester.pumpAndSettle();

    expect(find.text('Quản lý người xem'), findsOneWidget);
    expect(find.text('Cập nhật ngưỡng cảnh báo'), findsOneWidget);
  });

  testWidgets('viewer only sees read-only device actions on device page', (
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
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987000001', password: 'MatKhau123');

    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson(const <String, dynamic>{
            'device_id': 'dev-esp-001',
            'name': 'Phong ngu',
            'user_id': 'owner-001',
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
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const DevicePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Người xem'), findsWidgets);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Quản lý'));
    await tester.pumpAndSettle();

    expect(find.text('Quản lý người xem'), findsNothing);
    expect(find.text('Cập nhật ngưỡng cảnh báo'), findsNothing);
    expect(find.text('Đổi tên hiển thị'), findsOneWidget);
  });

  testWidgets('user can rename device locally on device page', (tester) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'owner-001',
        'name': 'Owner A',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987654321', password: 'MatKhau123');

    final deviceProvider = DeviceProvider(
      api: FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson(const <String, dynamic>{
            'device_id': 'dev-esp-001',
            'name': 'Phong ngu',
            'user_id': 'owner-001',
            'link_role': 'owner',
            'linked_users': <Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'owner-001',
                'name': 'Owner A',
                'link_role': 'owner',
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
      AuthTestShell(
        session: session,
        deviceProvider: deviceProvider,
        child: const DevicePage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Quản lý'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên hiển thị'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'May do phong ngu');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('May do phong ngu'), findsOneWidget);
    expect(deviceProvider.current?.name, 'May do phong ngu');
  });
}
