import 'package:shared_preferences/shared_preferences.dart';

class PushInstallationStorage {
  static const _installationIdKey = 'push_installation_id';

  Future<String> getOrCreateInstallationId({required String platform}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installationIdKey)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;

    final normalizedPlatform = platform.trim().isEmpty ? 'app' : platform.trim();
    final created =
        '$normalizedPlatform-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_installationIdKey, created);
    return created;
  }
}
