import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../models/health_reading.dart';
import '../models/alert_model.dart';
import '../models/device_model.dart';

/// API Service for REST endpoints
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _client = client ?? http.Client();

  /// Get vital signs for a device
  Future<List<HealthReading>> getVitals({
    required String deviceUid,
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        if (startTime != null)
          'start_time': (startTime.millisecondsSinceEpoch / 1000).toString(),
        if (endTime != null)
          'end_time': (endTime.millisecondsSinceEpoch / 1000).toString(),
      };

      final uri = Uri.parse(
        '$baseUrl${AppConfig.getVitalsEndpoint(deviceUid)}',
      ).replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;
        return items
            .map((item) => HealthReading.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch vitals: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// Get ECG data for a device
  Future<List<HealthReading>> getECGData({
    required String deviceUid,
    int limit = 10,
    String? qualityFilter,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        if (qualityFilter != null) 'quality_filter': qualityFilter,
      };

      final uri = Uri.parse(
        '$baseUrl${AppConfig.getECGEndpoint(deviceUid)}',
      ).replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;
        return items
            .map((item) => HealthReading.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch ECG data: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// Get summary statistics for a device
  Future<Map<String, dynamic>> getSummary({
    required String deviceUid,
    String period = '24h',
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl${AppConfig.getSummaryEndpoint(deviceUid)}',
      ).replace(queryParameters: {'period': period});

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to fetch summary: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// Get alerts for a device
  Future<List<AlertModel>> getAlerts({
    required String deviceUid,
    String? severity,
    bool? acknowledged,
    int limit = 100,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        if (severity != null) 'severity': severity,
        if (acknowledged != null) 'acknowledged': acknowledged.toString(),
      };

      final uri = Uri.parse(
        '$baseUrl${AppConfig.getAlertsEndpoint(deviceUid)}',
      ).replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;
        return items
            .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch alerts: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// Register a new device
  Future<DeviceModel> registerDevice({
    required String deviceUid,
    required String deviceType,
    String? userId, // Optional now
    String? firmwareVersion,
    String? macAddress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${AppConfig.registerDeviceEndpoint}');

      final body = {
        'device_uid': deviceUid,
        'device_type': deviceType,
        if (userId != null) 'user_id': userId,
        if (firmwareVersion != null) 'firmware_version': firmwareVersion,
        if (macAddress != null) 'mac_address': macAddress,
      };

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return DeviceModel.fromJson(data);
      } else {
        throw ApiException(
          'Failed to register device: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// API Exception class
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
