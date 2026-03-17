import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';

import 'support/test_helpers.dart';

void main() {
  test('parses latest reading from a direct object response', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-1/latest');
        return jsonResponse(<String, dynamic>{
          'timestamp': '2026-03-16T10:30:00Z',
          'device_id': 'dev-1',
          'heart_rate': 72,
        }, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;

    final point = await service.getLatestByDevice(deviceId: 'dev-1');

    expect(point.deviceId, 'dev-1');
    expect(point.hr, 72);
  });

  test('parses history and vitals from items list', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        if (options.path.contains('/history')) {
          return jsonResponse(<String, dynamic>{
            'count': 1,
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'timestamp': '2026-03-16T08:00:00Z',
                'device_id': 'dev-1',
                'heart_rate': 70,
              },
            ],
          }, 200);
        }

        return jsonResponse(<String, dynamic>{
          'count': 1,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'timestamp': '2026-03-16T09:00:00Z',
              'device_id': 'dev-1',
              'heart_rate': 74,
            },
          ],
        }, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;

    final history = await service.getHistoryByDevice(deviceId: 'dev-1');
    final vitals = await service.getVitalsByUser(userId: 'patient-001');

    expect(history.single.hr, 70);
    expect(vitals.single.hr, 74);
  });

  test('parses ecg items list and sends request payload correctly', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        if (options.path.endsWith('/ecg/request')) {
          expect(options.data, <String, dynamic>{
            'duration_seconds': 12,
            'sampling_rate': 300,
          });
          return jsonResponse(<String, dynamic>{'request_id': 'req-1'}, 200);
        }

        expect(options.path, '/api/v1/devices/dev-1/ecg');

        return jsonResponse(<String, dynamic>{
          'count': 1,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'timestamp': '2026-03-16T10:00:00Z', 'samples': <int>[1, 2, 3]},
          ],
        }, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;

    final items = await service.getEcgByDevice(deviceId: 'dev-1');
    final request = await service.requestEcg(
      deviceId: 'dev-1',
      durationSeconds: 12,
      samplingRate: 300,
    );

    expect(items, hasLength(1));
    expect(request['request_id'], 'req-1');
  });
}
