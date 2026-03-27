import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';

import 'support/test_helpers.dart';

void main() {
  test('parses latest reading from the device latest endpoint', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-1/latest');
        return jsonResponse(<String, dynamic>{
          'timestamp': '2026-03-16T10:30:00Z',
          'device_id': 'dev-1',
          'heart_rate': 72,
        }, 200);
      },
    );

    final point = await service.getLatestByDevice(deviceId: 'dev-1');

    expect(point.deviceId, 'dev-1');
    expect(point.hr, 72);
  });

  test('parses history from the device history endpoint', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-1/history');
        expect(options.queryParameters, <String, dynamic>{'limit': 100});
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
      },
    );

    final history = await service.getHistoryByDevice(deviceId: 'dev-1');

    expect(history, hasLength(1));
    expect(history.single.hr, 70);
  });

  test('reads summary from the device summary endpoint', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-1/summary');
        expect(options.queryParameters, <String, dynamic>{'period': '24h'});
        return jsonResponse(<String, dynamic>{
          'device_id': 'dev-1',
          'avg_hr': 73,
        }, 200);
      },
    );

    final summary = await service.getSummaryByDevice(deviceId: 'dev-1');

    expect(summary['device_id'], 'dev-1');
    expect(summary['avg_hr'], 73);
  });

  test('parses the newest ECG reading from the device ECG endpoint', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = HealthApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-1/ecg');

        return jsonResponse(<String, dynamic>{
          'count': 1,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'recorded_at': '2026-03-24T10:46:07.177Z',
              'device_id': 'dev-1',
              'ecg': <String, dynamic>{
                'waveform': <double>[0.12, 0.18, 0.05, -0.03, 0.22],
                'sampling_rate': 250,
                'quality': 'good',
                'lead_off': false,
                'ecg_hr': 72,
              },
            },
          ],
        }, 200);
      },
    );

    final reading = await service.getLatestEcgByDevice(deviceId: 'dev-1');

    expect(reading, isNotNull);
    expect(reading!.samplingRate, 250);
    expect(reading.ecgHr, 72);
    expect(reading.waveform, hasLength(5));
  });
}
