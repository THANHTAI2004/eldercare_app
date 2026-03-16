import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';

void main() {
  test('requestEcg returns success when result is received', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'patient-001',
    );
    provider.bindScope(
      userId: 'patient-001',
      deviceId: 'dev-1',
    );

    final result = await provider.requestEcg();

    expect(provider.status, AsyncStatus.success);
    expect(result['ecg_result'], isNotNull);
  });

  test('requestEcg marks unauthorized when session is missing', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(),
    );

    expect(
      () => provider.requestEcg(),
      throwsA(isA<StateError>()),
    );
    expect(provider.status, AsyncStatus.unauthorized);
  });
}

class _FakeHealthApiService extends HealthApiService {
  _FakeHealthApiService()
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  @override
  Future<Map<String, dynamic>> requestEcg({
    required String deviceId,
    int durationSeconds = 10,
    int samplingRate = 250,
  }) async {
    return <String, dynamic>{'request_id': 'req-1'};
  }

  @override
  Future<Map<String, dynamic>?> waitForEcgResult({
    required String deviceId,
    required int pollIntervalMs,
    DateTime? notBefore,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return <String, dynamic>{'samples': <int>[1, 2, 3]};
  }
}
