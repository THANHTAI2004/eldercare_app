import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/domain/models/vital_point.dart';

class VitalsCacheStorage {
  static const _latestPrefix = 'cache.latest.';
  static const _historyPrefix = 'cache.history.';

  Future<void> saveLatest({
    required String scopeKey,
    required VitalPoint point,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_latestPrefix$scopeKey',
        jsonEncode(point.toJson()),
      );
    } catch (_) {}
  }

  Future<VitalPoint?> loadLatest({required String scopeKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_latestPrefix$scopeKey');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return VitalPoint.fromJson(decoded);
      }
      if (decoded is Map) {
        return VitalPoint.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveHistory({
    required String scopeKey,
    required List<VitalPoint> points,
    int maxItems = 500,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = points.length <= maxItems
          ? points
          : points.sublist(points.length - maxItems);
      await prefs.setString(
        '$_historyPrefix$scopeKey',
        jsonEncode(trimmed.map((point) => point.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<List<VitalPoint>> loadHistory({required String scopeKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_historyPrefix$scopeKey');
      if (raw == null || raw.isEmpty) return const <VitalPoint>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <VitalPoint>[];
      return decoded
          .whereType<Map>()
          .map((item) => VitalPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const <VitalPoint>[];
    }
  }

  String scopeKey({
    required String userId,
    required String deviceId,
  }) {
    final normalizedUserId = userId.trim().isEmpty ? '-' : userId.trim();
    final normalizedDeviceId = deviceId.trim().isEmpty ? '-' : deviceId.trim();
    return '$normalizedUserId::$normalizedDeviceId';
  }
}
