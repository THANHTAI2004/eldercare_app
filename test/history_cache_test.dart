import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/vitals_cache_storage.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/history_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loadForDay falls back to cached history on network error', () async {
    final cache = VitalsCacheStorage();
    final cachedPoints = <VitalPoint>[
      VitalPoint(
        time: DateTime.parse('2026-03-16T08:00:00Z'),
        userId: 'patient-001',
        deviceId: 'dev-1',
        hr: 70,
      ),
    ];
    await cache.saveHistory(
      scopeKey: cache.scopeKey(userId: 'patient-001', deviceId: 'dev-1'),
      points: cachedPoints,
    );

    final provider = HistoryProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _ErrorHealthApiService(),
      cacheStorage: cache,
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'patient-001',
      authenticatedRole: 'patient',
    );

    await provider.bindScope(userId: 'patient-001', deviceId: 'dev-1');
    await provider.loadForDay(DateTime(2026, 3, 16));

    expect(provider.points, hasLength(1));
    expect(provider.isShowingCachedHistory, isTrue);
  });
}

class _ErrorHealthApiService extends HealthApiService {
  _ErrorHealthApiService()
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  @override
  Future<List<VitalPoint>> getHistoryByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    throw ApiRequestException(
      method: 'GET',
      path: '/api/v1/devices/$deviceId/history',
      message: 'network down',
    );
  }

  @override
  Future<List<VitalPoint>> getVitalsByUser({
    required String userId,
    String? deviceId,
    int limit = 100,
  }) async {
    throw ApiRequestException(
      method: 'GET',
      path: '/api/v1/users/$userId/vitals',
      message: 'network down',
    );
  }
}
