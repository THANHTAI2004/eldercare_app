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
      _read('API_BASE_URL', fallback: 'https://api.yourdomain.com');
  static String get apiKey =>
      _read('ADMIN_API_KEY', fallback: _read('API_KEY'));

  static String get loginUserId => _read('LOGIN_USER_ID');
  static String get loginPassword => _read('LOGIN_PASSWORD');
  static bool get hasLoginCredentials =>
      loginUserId.isNotEmpty && loginPassword.isNotEmpty;

  static String get defaultUserId => _read('USER_ID', fallback: 'dev-user-001');
  static String get defaultDeviceId =>
      _read('DEVICE_ID', fallback: 'dev-esp-001');

  static int get requestTimeoutMs =>
      _readInt('REQUEST_TIMEOUT_MS', fallback: 15000);
  static int get pollIntervalMs => _readInt('POLL_INTERVAL_MS', fallback: 2000);
}
