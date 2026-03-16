import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String _read(String key, {String fallback = ''}) {
    try {
      final value = dotenv.env[key]?.trim();
      if (value == null || value.isEmpty) return fallback;
      return value;
    } catch (_) {
      return fallback;
    }
  }

  static int _readInt(String key, {required int fallback}) {
    final raw = _read(key);
    return int.tryParse(raw) ?? fallback;
  }

  static String get apiBaseUrl =>
      _read('API_BASE_URL', fallback: 'https://api.eldercare.io.vn');
  static String get optionalApiKeyForDevOnly => kDebugMode
      ? _read('ADMIN_API_KEY', fallback: _read('API_KEY'))
      : '';

  static String get debugLoginUserId =>
      kDebugMode ? _read('LOGIN_USER_ID') : '';
  static String get debugLoginPassword =>
      kDebugMode ? _read('LOGIN_PASSWORD') : '';
  static bool get hasDebugLoginCredentials =>
      debugLoginUserId.isNotEmpty && debugLoginPassword.isNotEmpty;

  static String get debugDefaultUserId => kDebugMode ? _read('USER_ID') : '';
  static String get debugDefaultDeviceId =>
      kDebugMode ? _read('DEVICE_ID') : '';

  static int get requestTimeoutMs =>
      _readInt('REQUEST_TIMEOUT_MS', fallback: 15000);
  static int get pollIntervalMs => _readInt('POLL_INTERVAL_MS', fallback: 2000);
}
