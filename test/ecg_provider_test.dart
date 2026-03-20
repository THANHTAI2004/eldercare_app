import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';

void main() {
  test('requestEcg returns success when result is received', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(
        ecgResult: <String, dynamic>{'samples': <int>[1, 2, 3]},
      ),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-001',
    );
    provider.bindScope(deviceId: 'dev-1');

    final result = await provider.requestEcg();

    expect(provider.status, AsyncStatus.success);
    expect(
      provider.message,
      'Đã nhận được kết quả ECG mới cho thiết bị hiện tại.',
    );
    expect(result['ecg_result'], isNotNull);
  });

  test('requestEcg returns empty when polling times out', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(ecgResult: null),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-001',
    );
    provider.bindScope(deviceId: 'dev-1');

    final result = await provider.requestEcg();

    expect(provider.status, AsyncStatus.empty);
    expect(
      provider.message,
      'Đã gửi lệnh ECG nhưng chưa có kết quả mới trong thời gian chờ.',
    );
    expect(result['request_id'], 'req-1');
    expect(result.containsKey('ecg_result'), isFalse);
  });

  test('requestEcg marks unauthorized when session is missing', () async {
    final provider = EcgProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(
        ecgResult: <String, dynamic>{'samples': <int>[1, 2, 3]},
      ),
    );

    expect(
      () => provider.requestEcg(),
      throwsA(isA<StateError>()),
    );
    expect(provider.status, AsyncStatus.unauthorized);
  });
}

class _FakeHealthApiService extends HealthApiService {
  _FakeHealthApiService({required this.ecgResult})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final Map<String, dynamic>? ecgResult;

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
    return ecgResult;
  }
}
