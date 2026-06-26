import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';

void main() {
  test('refreshLatest returns success when ECG waveform is available', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(
        reading: EcgReading(
          recordedAt: DateTime.parse('2026-03-24T10:46:07.177Z'),
          waveform: const <double>[0.12, 0.18, 0.05, -0.03, 0.22],
          samplingRate: 250,
          quality: 'good',
          leadOff: false,
        ),
      ),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-001',
    );
    provider.bindScope(deviceId: 'dev-1');

    await provider.refreshLatest();

    expect(provider.status, AsyncStatus.success);
    expect(provider.latest, isNotNull);
    expect(provider.latest!.waveform, hasLength(5));
    expect(provider.latest!.samplingRate, 250);
  });

  test('refreshLatest returns empty when ECG is missing', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(reading: null),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-001',
    );
    provider.bindScope(deviceId: 'dev-1');

    await provider.refreshLatest();

    expect(provider.status, AsyncStatus.empty);
    expect(provider.latest, isNull);
  });

  test('refreshLatest marks unauthorized when session is missing', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(reading: null),
    );

    await provider.refreshLatest();

    expect(provider.status, AsyncStatus.unauthorized);
    expect(provider.latest, isNull);
  });
}

class _FakeHealthApiService extends HealthApiService {
  _FakeHealthApiService({required this.reading})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final EcgReading? reading;

  @override
  Future<EcgReading?> getLatestEcgByDevice({
    required String deviceId,
    int limit = 1,
  }) async {
    return reading;
  }
}
