import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

const int _maxEcgQueryLimit = 100;

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
    final safeLimit = limit.clamp(1, _maxEcgQueryLimit);
    final json = await _client.getJson(
      '/api/v1/devices/$deviceId/ecg',
      query: <String, dynamic>{'limit': safeLimit},
    );
    return _readItems(json);
  }

  Future<EcgReading?> getLatestEcgByDevice({
    required String deviceId,
    int limit = 1,
  }) async {
    final items = await getEcgByDevice(deviceId: deviceId, limit: limit);
    for (final item in items) {
      final reading = EcgReading.fromJson(item);
      if (reading != null) return reading;
    }
    return null;
  }

  Future<List<EcgReading>> getEcgReadingsByDevice({
    required String deviceId,
    int limit = 100,
  }) async {
    final items = await getEcgByDevice(deviceId: deviceId, limit: limit);
    return items
        .map(EcgReading.fromJson)
        .whereType<EcgReading>()
        .toList(growable: false);
  }

  Future<void> requestEcgByDevice({required String deviceId}) async {
    await _client.postJson('/api/v1/devices/$deviceId/ecg/request');
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
}
