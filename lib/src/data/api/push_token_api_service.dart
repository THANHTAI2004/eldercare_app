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
    required String installationId,
    required String fcmToken,
    required String platform,
  }) async {
    final normalizedInstallationId = installationId.trim();
    final normalizedToken = fcmToken.trim();
    final normalizedPlatform = platform.trim();
    if (normalizedInstallationId.isEmpty ||
        normalizedToken.isEmpty ||
        normalizedPlatform.isEmpty ||
        _path.isEmpty) {
      return;
    }

    try {
      await _client.postJson(
        _path,
        data: <String, dynamic>{
          'installation_id': normalizedInstallationId,
          'fcm_token': normalizedToken,
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

  Future<void> deletePushToken({required String installationId}) async {
    final normalizedInstallationId = installationId.trim();
    if (normalizedInstallationId.isEmpty || _path.isEmpty) return;

    final deletePath = '$_path/${Uri.encodeComponent(normalizedInstallationId)}';
    try {
      await _client.deleteJson(deletePath);
    } on ApiRequestException catch (e) {
      if (_isUnsupportedStatus(e.statusCode)) {
        throw PushTokenEndpointUnsupportedException(
          path: deletePath,
          statusCode: e.statusCode,
        );
      }
      rethrow;
    }
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    final withLeadingSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
  }

  static bool _isUnsupportedStatus(int? statusCode) {
    return statusCode == 404 || statusCode == 405 || statusCode == 501;
  }
}
