import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/alerts_api_service.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';

import 'support/test_helpers.dart';

void main() {
  test('getMyAlerts reads /api/v1/me/alerts with device filter', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = AlertsApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/me/alerts');
        expect(options.queryParameters, <String, dynamic>{
          'device_id': 'dev-1',
        });
        return jsonResponse(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'alert_id': 'alert-001',
              'title': 'Nhip tim bat thuong',
              'severity': 'critical',
              'created_at': '2026-03-13T10:00:00Z',
              'device_id': 'dev-1',
            },
          ],
        }, 200);
      },
    );

    final alerts = await service.getMyAlerts(deviceId: 'dev-1');

    expect(alerts, hasLength(1));
    expect(alerts.single.deviceId, 'dev-1');
  });
}
