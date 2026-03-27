import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/device_thresholds.dart';

class DeviceThresholdsApiService {
  DeviceThresholdsApiService({ApiClient? client})
    : _client = client ?? ApiClient.fromEnv();

  final ApiClient _client;

  Future<DeviceThresholds> getDeviceThresholds({
    required String deviceId,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    final json = await _client.getJson(
      '/api/v1/devices/$normalizedDeviceId/thresholds',
    );
    return DeviceThresholds.fromJson(_unwrapThresholds(json));
  }

  Future<DeviceThresholds> updateDeviceThresholds({
    required String deviceId,
    required Map<String, dynamic> payload,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    final json = await _client.patchJson(
      '/api/v1/devices/$normalizedDeviceId/thresholds',
      data: payload,
    );

    final normalized = _unwrapThresholds(json);
    if (normalized.isNotEmpty) {
      return DeviceThresholds.fromJson(normalized);
    }
    return DeviceThresholds.fromJson(payload);
  }

  Map<String, dynamic> _unwrapThresholds(Map<String, dynamic> json) {
    final candidates = <dynamic>[
      json['thresholds'],
      json['item'],
      json['data'],
      json,
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        return candidate;
      }
      if (candidate is Map) {
        return Map<String, dynamic>.from(candidate);
      }
    }

    return const <String, dynamic>{};
  }
}
