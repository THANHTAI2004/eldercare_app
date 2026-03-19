import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/vitals_cache_storage.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('refreshLatest falls back to cached latest on network error', () async {
    final cache = VitalsCacheStorage();
    final cachedPoint = VitalPoint(
      time: DateTime.parse('2026-03-16T10:00:00Z'),
      userId: 'user-001',
      deviceId: 'dev-1',
      hr: 71,
    );
    await cache.saveLatest(
      scopeKey: cache.scopeKey(userId: '', deviceId: 'dev-1'),
      point: cachedPoint,
    );

    final provider = RealtimeProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _ErrorHealthApiService(),
      cacheStorage: cache,
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-001',
    );

    await provider.init(deviceId: 'dev-1');

    expect(provider.latest?.hr, 71);
    expect(provider.isShowingCachedLatest, isTrue);
  });
}

class _ErrorHealthApiService extends HealthApiService {
  _ErrorHealthApiService()
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  @override
  Future<VitalPoint> getLatestByDevice({required String deviceId}) async {
    throw ApiRequestException(
      method: 'GET',
      path: '/api/v1/devices/$deviceId/latest',
      message: 'network down',
    );
  }

  @override
  Future<VitalPoint> getLatestByUser({
    required String userId,
    String? deviceId,
  }) async {
    throw ApiRequestException(
      method: 'GET',
      path: '/api/v1/users/$userId/latest',
      message: 'network down',
    );
  }
}
