import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/device.dart';

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

  List<Map<String, dynamic>> _extractMany(Map<String, dynamic> json) {
    final candidates = <dynamic>[
      json['items'],
      json['devices'],
      json['data'],
      json['results'],
    ];

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
