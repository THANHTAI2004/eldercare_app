import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/device_registration_result.dart';

class DeviceApiService {
  DeviceApiService({ApiClient? client})
    : _client = client ?? ApiClient.fromEnv();

  final ApiClient _client;

  Future<List<Device>> getMyDevices() async {
    final json = await _client.getJson('/api/v1/me/devices');
    return _extractMany(json)
        .map(Device.fromServerJson)
        .where((device) => device.resolvedDeviceId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> claimDevice({
    required String deviceId,
    required String pairingCode,
  }) async {
    await _client.postJson(
      '/api/v1/devices/$deviceId/claim',
      data: <String, dynamic>{
        'pairing_code': pairingCode.trim(),
      },
    );
  }

  Future<DeviceRegistrationResult> registerDevice({
    required String deviceId,
    String? deviceName,
    String? deviceType,
    String? firmwareVersion,
    String? pairingCode,
  }) async {
    final payload = <String, dynamic>{'device_id': deviceId.trim()};

    final normalizedName = deviceName?.trim() ?? '';
    final normalizedType = deviceType?.trim() ?? '';
    final normalizedFirmwareVersion = firmwareVersion?.trim() ?? '';
    final normalizedPairingCode = pairingCode?.trim() ?? '';

    if (normalizedName.isNotEmpty) {
      payload['device_name'] = normalizedName;
    }
    if (normalizedType.isNotEmpty) {
      payload['device_type'] = normalizedType;
    }
    if (normalizedFirmwareVersion.isNotEmpty) {
      payload['firmware_version'] = normalizedFirmwareVersion;
    }
    if (normalizedPairingCode.isNotEmpty) {
      payload['pairing_code'] = normalizedPairingCode;
    }

    final json = await _client.postJson(
      '/api/v1/devices/register',
      data: payload,
    );
    return DeviceRegistrationResult.fromJson(json);
  }

  Future<List<DeviceLinkedUser>> getLinkedUsers({
    required String deviceId,
  }) async {
    final json = await _client.getJson(
      '/api/v1/devices/$deviceId/linked-users',
    );
    return _extractMany(json)
        .map(DeviceLinkedUser.fromJson)
        .where((user) => user.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> addViewer({
    required String deviceId,
    required String userId,
  }) async {
    final normalizedUserId = userId.trim();
    await _client.postJson(
      '/api/v1/devices/$deviceId/viewers',
      data: <String, dynamic>{'user_id': normalizedUserId},
    );
  }

  Future<void> removeViewer({
    required String deviceId,
    required String userId,
  }) async {
    await _client.deleteJson('/api/v1/devices/$deviceId/viewers/$userId');
  }

  List<Map<String, dynamic>> _extractMany(Map<String, dynamic> json) {
    // Primary contract is {"count": ..., "items": [...] } from backend.
    // `devices` is kept only for backward compatibility with older payloads.
    final candidates = <dynamic>[json['items'], json['devices']];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    if (json['device_id'] != null ||
        json['deviceId'] != null ||
        json['id'] != null) {
      return <Map<String, dynamic>>[json];
    }

    return const <Map<String, dynamic>>[];
  }
}
