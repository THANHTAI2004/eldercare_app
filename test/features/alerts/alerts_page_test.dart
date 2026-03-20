import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/alerts_api_service.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/alert_item.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/alerts/alerts_page.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('viewer does not see acknowledge action on alerts page', (
    tester,
  ) async {
    final alertsProvider = AlertsProvider(
      api: _FakeAlertsApiService(
        items: <AlertItem>[
          AlertItem(
            id: 'alert-001',
            title: 'Nhịp tim bất thường',
            message: 'HR > 130',
            severity: 'critical',
            createdAt: DateTime.parse('2026-03-13T10:00:00Z'),
            acknowledged: false,
            userId: 'viewer-001',
            deviceId: 'dev-esp-001',
          ),
        ],
      ),
    )..handleSessionState(
        isAuthenticated: true,
        authenticatedUserId: 'viewer-001',
      );

    final deviceProvider = DeviceProvider(
      api: _FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson(const <String, dynamic>{
            'device_id': 'dev-esp-001',
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
      authenticatedUserId: 'viewer-001',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AlertsProvider>.value(value: alertsProvider),
          ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ],
        child: const MaterialApp(home: AlertsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đánh dấu đã xử lý'), findsNothing);
    expect(
      find.text(
        'Bạn đang ở chế độ chỉ xem trên thiết bị này. Chỉ chủ thiết bị mới có thể đánh dấu đã xử lý cảnh báo.',
      ),
      findsOneWidget,
    );
  });
}

class _FakeAlertsApiService extends AlertsApiService {
  _FakeAlertsApiService({required this.items})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<AlertItem> items;

  @override
  Future<List<AlertItem>> getAlertsByDevice({required String deviceId}) async {
    return items;
  }
}

class _FakeDeviceApiService extends DeviceApiService {
  _FakeDeviceApiService({required this.devices})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<Device> devices;

  @override
  Future<List<Device>> getMyDevices() async => devices;
}
