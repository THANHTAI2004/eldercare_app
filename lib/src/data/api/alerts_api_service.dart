import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/alert_item.dart';

class AlertsApiService {
  AlertsApiService({ApiClient? client})
    : _client = client ?? ApiClient.fromEnv();

  final ApiClient _client;

  Future<List<AlertItem>> getAlertsByDevice({required String deviceId}) async {
    final normalizedDeviceId = deviceId.trim();
    final json = await _client.getJson(
      '/api/v1/devices/$normalizedDeviceId/alerts',
    );
    var reboundDeviceCount = 0;
    final items = _extractMany(json)
        .map(AlertItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .map((item) {
          if (normalizedDeviceId.isEmpty) {
            return item;
          }

          final currentDeviceId = item.deviceId?.trim() ?? '';
          if (currentDeviceId == normalizedDeviceId) {
            return item;
          }

          reboundDeviceCount += 1;
          return item.copyWith(deviceId: normalizedDeviceId);
        })
        .toList(growable: false);

    if (reboundDeviceCount > 0) {
      debugPrint(
        '[AlertsApiService] Rebound device_id for '
        '$reboundDeviceCount alert(s) on $normalizedDeviceId',
      );
    }

    return items;
  }

  Future<Map<String, dynamic>> acknowledgeAlert({required String alertId}) {
    return _client.postJson('/api/v1/alerts/$alertId/acknowledge');
  }

  List<Map<String, dynamic>> _extractMany(Map<String, dynamic> json) {
    final candidates = <dynamic>[
      json['items'],
      json['alerts'],
      json['data'],
      json['results'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
      }
    }

    if (json['alert_id'] != null || json['id'] != null) {
      return <Map<String, dynamic>>[json];
    }

    return const <Map<String, dynamic>>[];
  }
}
