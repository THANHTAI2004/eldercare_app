import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_thresholds_api_service.dart';
import 'package:eldercare_app/src/data/local/device_thresholds_storage.dart';
import 'package:eldercare_app/src/domain/models/device_thresholds.dart';
import 'package:eldercare_app/src/state/device_thresholds_provider.dart';

import 'support/test_helpers.dart';

void main() {
  setUp(setUpSharedPreferences);

  test('loadThresholds falls back to cached thresholds when GET is unsupported', () async {
    const cached = DeviceThresholds(
      spo2Low: 92,
      spo2Critical: 88,
      tempLow: 35.5,
      tempHigh: 37.8,
      tempCritical: 39,
      hrLow: 55,
      hrLowCritical: 45,
      hrHigh: 110,
      hrCritical: 130,
    );

    final storage = DeviceThresholdsStorage();
    await storage.save(deviceId: 'dev-1', thresholds: cached);

    final provider = DeviceThresholdsProvider(
      api: _FakeDeviceThresholdsApiService(
        loadError: ApiRequestException(
          method: 'GET',
          path: '/api/v1/devices/dev-1/thresholds',
          message: 'Method Not Allowed',
          statusCode: 405,
        ),
      ),
      storage: storage,
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-1',
    );
    provider.bindDevice('dev-1');

    await provider.loadThresholds();

    expect(provider.thresholds?.spo2Low, 92);
    expect(provider.error, isNull);
    expect(provider.infoMessage, isNotNull);
    expect(provider.infoMessage, contains('May chu hien chua ho tro'));
  });

  test('saveThresholds caches the latest saved payload locally', () async {
    const saved = DeviceThresholds(
      spo2Low: 91,
      spo2Critical: 87,
      tempLow: 35.4,
      tempHigh: 37.7,
      tempCritical: 38.9,
      hrLow: 54,
      hrLowCritical: 44,
      hrHigh: 111,
      hrCritical: 131,
    );

    final storage = DeviceThresholdsStorage();
    final provider = DeviceThresholdsProvider(
      api: _FakeDeviceThresholdsApiService(savedThresholds: saved),
      storage: storage,
    );

    provider.handleSessionState(
      isAuthenticated: true,
      authenticatedUserId: 'user-1',
    );
    provider.bindDevice('dev-1');

    final ok = await provider.saveThresholds(saved);
    final cached = await storage.load(deviceId: 'dev-1');

    expect(ok, isTrue);
    expect(cached?.toPayload(), saved.toPayload());
  });
}

class _FakeDeviceThresholdsApiService extends DeviceThresholdsApiService {
  _FakeDeviceThresholdsApiService({this.savedThresholds, this.loadError});

  final DeviceThresholds? savedThresholds;
  final ApiRequestException? loadError;

  @override
  Future<DeviceThresholds> getDeviceThresholds({required String deviceId}) async {
    if (loadError != null) throw loadError!;
    return savedThresholds ?? const DeviceThresholds();
  }

  @override
  Future<DeviceThresholds> updateDeviceThresholds({
    required String deviceId,
    required Map<String, dynamic> payload,
  }) async {
    return savedThresholds ?? DeviceThresholds.fromJson(payload);
  }
}
