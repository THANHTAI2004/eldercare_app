import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/vitals_cache_storage.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';

import 'support/test_helpers.dart';

void main() {
  setUp(() {
    setUpSharedPreferences();
  });

  test('init loads latest reading successfully for selected device', () async {
    final provider = RealtimeProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(
        pointsByDeviceId: <String, VitalPoint>{
          'dev-1': VitalPoint(
            time: DateTime.parse('2026-03-16T10:30:00Z'),
            deviceId: 'dev-1',
            hr: 72,
          ),
        },
      ),
      cacheStorage: VitalsCacheStorage(),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'patient-001',
      authenticatedRole: 'patient',
    );

    await provider.init(userId: 'patient-001', deviceId: 'dev-1');

    expect(provider.latestStatus, AsyncStatus.success);
    expect(provider.latest?.deviceId, 'dev-1');
    expect(provider.latest?.hr, 72);
    expect(provider.isShowingCachedLatest, isFalse);
  });

  test('changeUser reloads latest when selected device changes', () async {
    final provider = RealtimeProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(
        pointsByDeviceId: <String, VitalPoint>{
          'dev-1': VitalPoint(
            time: DateTime.parse('2026-03-16T10:30:00Z'),
            deviceId: 'dev-1',
            hr: 72,
          ),
          'dev-2': VitalPoint(
            time: DateTime.parse('2026-03-16T10:35:00Z'),
            deviceId: 'dev-2',
            hr: 80,
          ),
        },
      ),
      cacheStorage: VitalsCacheStorage(),
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'patient-001',
      authenticatedRole: 'patient',
    );

    await provider.init(userId: 'patient-001', deviceId: 'dev-1');
    await provider.changeUser('patient-001', deviceId: 'dev-2');

    expect(provider.latestStatus, AsyncStatus.success);
    expect(provider.deviceId, 'dev-2');
    expect(provider.latest?.deviceId, 'dev-2');
    expect(provider.latest?.hr, 80);
  });

  test('init marks unauthorized when session is missing', () async {
    final provider = RealtimeProvider(
      client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
      api: _FakeHealthApiService(pointsByDeviceId: const <String, VitalPoint>{}),
      cacheStorage: VitalsCacheStorage(),
    );

    await provider.init(userId: 'patient-001', deviceId: 'dev-1');

    expect(provider.latestStatus, AsyncStatus.unauthorized);
    expect(provider.error, 'Phien dang nhap khong hop le hoac da het han');
  });
}

class _FakeHealthApiService extends HealthApiService {
  _FakeHealthApiService({required this.pointsByDeviceId})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final Map<String, VitalPoint> pointsByDeviceId;

  @override
  Future<VitalPoint> getLatestByDevice({required String deviceId}) async {
    final point = pointsByDeviceId[deviceId];
    if (point == null) {
      throw ApiRequestException(
        method: 'GET',
        path: '/api/v1/devices/$deviceId/latest',
        message: 'No data found',
        statusCode: 404,
      );
    }
    return point;
  }

  @override
  Future<VitalPoint> getLatestByUser({
    required String userId,
    String? deviceId,
  }) async {
    return getLatestByDevice(deviceId: deviceId ?? userId);
  }
}
