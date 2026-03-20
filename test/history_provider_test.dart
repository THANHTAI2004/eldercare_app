import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/history_provider.dart';

void main() {
  test('loadForDay returns success when selected day has points', () async {
    final provider = HistoryProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(
        history: <VitalPoint>[
          VitalPoint(
            time: DateTime.parse('2026-03-16T08:00:00Z'),
            deviceId: 'dev-1',
            hr: 72,
          ),
          VitalPoint(
            time: DateTime.parse('2026-03-15T08:00:00Z'),
            deviceId: 'dev-1',
            hr: 65,
          ),
        ],
      ),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-001',
    );

    await provider.bindScope(deviceId: 'dev-1');
    await provider.loadForDay(DateTime(2026, 3, 16));

    expect(provider.status, AsyncStatus.success);
    expect(provider.metricPointsForSelectedDay(Metric.hr), hasLength(1));
  });
}

class _FakeHealthApiService extends HealthApiService {
  _FakeHealthApiService({required this.history})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<VitalPoint> history;

  @override
  Future<List<VitalPoint>> getHistoryByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    return history;
  }
}
