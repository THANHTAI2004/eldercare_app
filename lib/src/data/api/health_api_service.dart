import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class HealthApiService {
  HealthApiService({ApiClient? client})
    : _client = client ?? ApiClient.fromEnv();

  final ApiClient _client;

  Future<Map<String, dynamic>> health() => _client.getJson('/health');

  Future<VitalPoint> getLatestByDevice({required String deviceId}) async {
    final json = await _client.getJson('/api/v1/devices/$deviceId/latest');
    return VitalPoint.fromJson(json);
  }

  Future<List<VitalPoint>> getHistoryByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    final json = await _client.getJson(
      '/api/v1/devices/$deviceId/history',
      query: <String, dynamic>{'limit': limit},
    );
    return _readItems(json).map(VitalPoint.fromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> getSummaryByDevice({
    required String deviceId,
    String period = '24h',
  }) {
    return _client.getJson(
      '/api/v1/devices/$deviceId/summary',
      query: <String, dynamic>{'period': period},
    );
  }

  Future<List<Map<String, dynamic>>> getEcgByDevice({
    required String deviceId,
    int limit = 10,
  }) async {
    final json = await _client.getJson(
      '/api/v1/devices/$deviceId/ecg',
      query: <String, dynamic>{'limit': limit},
    );
    return _readItems(json);
  }

  Future<Map<String, dynamic>> requestEcg({
    required String deviceId,
    int durationSeconds = 10,
    int samplingRate = 250,
  }) {
    return _client.postJson(
      '/api/v1/devices/$deviceId/ecg/request',
      data: <String, dynamic>{
        'duration_seconds': durationSeconds,
        'sampling_rate': samplingRate,
      },
    );
  }

  Future<Map<String, dynamic>?> waitForEcgResult({
    required String deviceId,
    required int pollIntervalMs,
    DateTime? notBefore,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final items = await getEcgByDevice(deviceId: deviceId, limit: 5);
      for (final item in items) {
        final itemTime = _readItemTime(item);
        if (notBefore == null ||
            itemTime == null ||
            !itemTime.isBefore(notBefore.toUtc())) {
          return item;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: pollIntervalMs));
    }
    return null;
  }

  List<Map<String, dynamic>> _readItems(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      return const <Map<String, dynamic>>[];
    }
    return items
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  DateTime? _readItemTime(Map<String, dynamic> json) {
    try {
      return VitalPoint.fromJson(json).time.toUtc();
    } catch (_) {
      return null;
    }
  }
}
