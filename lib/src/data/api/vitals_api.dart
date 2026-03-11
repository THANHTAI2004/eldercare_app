import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class VitalsApi {
  VitalsApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> health() {
    return _client.getJson('/health');
  }

  Future<VitalPoint> latest({required String userId}) async {
    final json = await _client.getJson('/api/v1/users/$userId/latest');
    final item = _extractOne(json);
    return VitalPoint.fromJson(item);
  }

  Future<List<VitalPoint>> vitals({
    required String userId,
    int limit = 300,
  }) async {
    final json = await _client.getJson(
      '/api/v1/users/$userId/vitals',
      query: {'limit': limit},
    );

    return _extractMany(json)
        .map((e) => VitalPoint.fromJson(e))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> ecg({
    required String userId,
    int limit = 10,
  }) async {
    final json = await _client.getJson(
      '/api/v1/users/$userId/ecg',
      query: {'limit': limit},
    );
    return _extractMany(json);
  }

  Future<Map<String, dynamic>> summary({
    required String userId,
    String period = '24h',
  }) {
    return _client.getJson(
      '/api/v1/users/$userId/summary',
      query: {'period': period},
    );
  }

  Future<Map<String, dynamic>> requestEcg({
    required String deviceId,
    required String userId,
    int durationSeconds = 10,
    int samplingRate = 250,
  }) {
    return _client.postJson(
      '/api/v1/devices/$deviceId/ecg/request',
      data: {
        'user_id': userId,
        'duration_seconds': durationSeconds,
        'sampling_rate': samplingRate,
      },
    );
  }

  Future<Map<String, dynamic>?> waitForEcgResult({
    required String userId,
    required int pollIntervalMs,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final items = await ecg(userId: userId, limit: 1);
      if (items.isNotEmpty) return items.first;
      await Future<void>.delayed(Duration(milliseconds: pollIntervalMs));
    }
    return null;
  }

  List<Map<String, dynamic>> _extractMany(Map<String, dynamic> json) {
    final candidates = <dynamic>[
      json['items'],
      json['points'],
      json['data'],
      json['results'],
      json['readings'],
    ];

    for (final c in candidates) {
      if (c is List) {
        return c
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    }

    if (json.isNotEmpty) return <Map<String, dynamic>>[json];
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractOne(Map<String, dynamic> json) {
    const oneKeys = ['item', 'data', 'latest', 'reading', 'result'];
    for (final key in oneKeys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return json;
  }
}
