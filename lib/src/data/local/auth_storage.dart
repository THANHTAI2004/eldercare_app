import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SecureKeyValueStore {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

class AuthStorage {
  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _currentUserKey = 'auth.current_user';

  AuthStorage({SecureKeyValueStore? secureStore})
    : _secureStore = secureStore ?? const FlutterSecureKeyValueStore();

  final SecureKeyValueStore _secureStore;

  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStore.write(key: _accessTokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> loadAccessToken() async {
    final token = await _safeReadSecure(_accessTokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStore.write(key: _refreshTokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> loadRefreshToken() async {
    final token = await _safeReadSecure(_refreshTokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<void> saveCurrentUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(user));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadCurrentUser() async {
    String? raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_currentUserKey);
    } catch (_) {
      return null;
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> clearTokens() async {
    try {
      await _secureStore.delete(key: _accessTokenKey);
      await _secureStore.delete(key: _refreshTokenKey);
    } catch (_) {}
  }

  Future<void> clearRefreshToken() async {
    try {
      await _secureStore.delete(key: _refreshTokenKey);
    } catch (_) {}
  }

  Future<void> clearCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
    } catch (_) {}
  }

  Future<void> clear() async {
    await clearTokens();
    await clearCurrentUser();
  }

  Future<String?> _safeReadSecure(String key) async {
    try {
      return await _secureStore.read(key: key);
    } catch (_) {
      return null;
    }
  }
}
