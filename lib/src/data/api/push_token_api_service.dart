import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';

class PushTokenEndpointUnsupportedException implements Exception {
  const PushTokenEndpointUnsupportedException({
    required this.path,
    this.statusCode,
  });

  final String path;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode?.toString() ?? 'unknown';
    return 'Push token endpoint not supported at $path ($status)';
  }
}

class PushTokenApiService {
  PushTokenApiService({ApiClient? client, String? path})
    : _client = client ?? ApiClient.fromEnv(),
      _path = _normalizePath(path ?? Env.pushTokenPath);

  final ApiClient _client;
  final String _path;

  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    final normalizedToken = token.trim();
    final normalizedPlatform = platform.trim();
    if (normalizedToken.isEmpty ||
        normalizedPlatform.isEmpty ||
        _path.isEmpty) {
      return;
    }

    try {
      await _client.postJson(
        _path,
        data: <String, dynamic>{
          'token': normalizedToken,
          'platform': normalizedPlatform,
        },
      );
    } on ApiRequestException catch (e) {
      if (_isUnsupportedStatus(e.statusCode)) {
        throw PushTokenEndpointUnsupportedException(
          path: _path,
          statusCode: e.statusCode,
        );
      }
      rethrow;
    }
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  static bool _isUnsupportedStatus(int? statusCode) {
    return statusCode == 404 || statusCode == 405 || statusCode == 501;
  }
}
