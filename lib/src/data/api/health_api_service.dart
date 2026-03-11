import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class HealthApiService {
  HealthApiService({ApiClient? client}) : _client = client ?? ApiClient.fromEnv();

  final ApiClient _client;

  Future<Map<String, dynamic>> health() => _client.getJson('/health');

  Future<VitalPoint> getLatestByUser({required String userId}) async {
    final json = await _client.getJson('/api/v1/users/$userId/latest');
    return VitalPoint.fromJson(_extractOne(json));
  }

  Future<List<VitalPoint>> getVitalsByUser({
    required String userId,
    int limit = 100,
  }) async {
    final json = await _client.getJson(
      '/api/v1/users/$userId/vitals',
      query: <String, dynamic>{'limit': limit},
    );
    return _extractMany(json).map(VitalPoint.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getEcgByUser({
    required String userId,
    int limit = 10,
  }) async {
    final json = await _client.getJson(
      '/api/v1/users/$userId/ecg',
      query: <String, dynamic>{'limit': limit},
    );
    return _extractMany(json);
  }

  Future<Map<String, dynamic>> getSummaryByUser({
    required String userId,
    String period = '24h',
  }) {
    return _client.getJson(
      '/api/v1/users/$userId/summary',
      query: <String, dynamic>{'period': period},
    );
  }

  Future<VitalPoint> getLatestByDevice({required String deviceId}) async {
    final json = await _client.getJson('/api/v1/devices/$deviceId/latest');
    return VitalPoint.fromJson(_extractOne(json));
  }

  Future<List<VitalPoint>> getHistoryByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    final json = await _client.getJson(
      '/api/v1/devices/$deviceId/history',
      query: <String, dynamic>{'limit': limit},
    );
    return _extractMany(json).map(VitalPoint.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> requestEcg({
    required String userId,
    required String deviceId,
    int durationSeconds = 10,
    int samplingRate = 250,
  }) {
    return _client.postJson(
      '/api/v1/devices/$deviceId/ecg/request',
      data: <String, dynamic>{
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
      final items = await getEcgByUser(userId: userId, limit: 1);
      if (items.isNotEmpty) {
        return items.first;
      }
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
      json['records'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractOne(Map<String, dynamic> json) {
    const oneKeys = <String>['item', 'data', 'latest', 'reading', 'result'];
    for (final key in oneKeys) {
      final value = json[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return json;
  }
}
