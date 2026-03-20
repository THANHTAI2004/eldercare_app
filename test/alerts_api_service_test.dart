import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/alerts_api_service.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';

import 'support/test_helpers.dart';

void main() {
  test('getAlertsByDevice reads /api/v1/devices/{deviceId}/alerts', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = AlertsApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-1/alerts');
        return jsonResponse(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'alert_id': 'alert-001',
              'title': 'Nhịp tim bất thường',
              'severity': 'critical',
              'created_at': '2026-03-13T10:00:00Z',
              'device_id': 'dev-1',
            },
          ],
        }, 200);
      },
    );

    final alerts = await service.getAlertsByDevice(deviceId: 'dev-1');

    expect(alerts, hasLength(1));
    expect(alerts.single.deviceId, 'dev-1');
  });
}
