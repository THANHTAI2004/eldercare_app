import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/domain/models/device_thresholds.dart';

class DeviceThresholdsStorage {
  static const _keyPrefix = 'device_thresholds::';

  Future<DeviceThresholds?> load({required String deviceId}) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(normalizedDeviceId));
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DeviceThresholds.fromJson(decoded);
      }
      if (decoded is Map) {
        return DeviceThresholds.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}

    return null;
  }

  Future<void> save({
    required String deviceId,
    required DeviceThresholds thresholds,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(normalizedDeviceId),
      jsonEncode(thresholds.toPayload()),
    );
  }

  Future<void> clear({required String deviceId}) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(normalizedDeviceId));
  }

  String _keyFor(String deviceId) => '$_keyPrefix$deviceId';
}
