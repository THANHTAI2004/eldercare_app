import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required ApiClient client,
    required AuthApiService authApi,
  }) : _client = client,
       _authApi = authApi {
    _client.configureAuthCallbacks(
      onRefreshAccessToken: _refreshAccessToken,
      onUnauthorized: _handleUnauthorized,
    );
  }

  final ApiClient _client;
  final AuthApiService _authApi;

  Future<void>? _bootstrapFuture;
  bool isBootstrapping = false;
  bool isAuthenticating = false;

  AuthTokens? _tokens;
  Map<String, dynamic>? currentUser;
  String? error;
  int? lastErrorStatusCode;

  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;
  bool get isAuthenticated =>
      accessToken != null && accessToken!.trim().isNotEmpty;

  String get authenticatedUserId {
    final candidates = <dynamic>[
      currentUser?['user_id'],
      currentUser?['userId'],
      currentUser?['id'],
      currentUser?['username'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String get authenticatedRole =>
      currentUser?['role']?.toString().trim().toLowerCase() ?? '';

  bool get isUserScopedSession =>
      isAuthenticated &&
      authenticatedUserId.isNotEmpty &&
      authenticatedRole != 'admin' &&
      authenticatedRole != 'caregiver';

  Future<void> bootstrap() {
    return _bootstrapFuture ??= _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    isBootstrapping = true;
    notifyListeners();

    try {
      final restored = await restoreSession(silent: true);
      if (!restored && Env.hasDebugLoginCredentials) {
        await login(silent: true);
      }
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> restoreSession({bool silent = false}) async {
    if (!silent) {
      isAuthenticating = true;
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();
    }

    try {
      _tokens = await _authApi.restoreSessionTokens();
      currentUser = await _authApi.loadSavedCurrentUser();

      if (_tokens == null || _tokens!.accessToken.isEmpty) {
        return false;
      }

      currentUser = await _authApi.me();
      return true;
    } catch (e) {
      if (!silent) {
        error = _friendlyError(
          e,
          fallback: 'Khong the khoi phuc phien dang nhap',
        );
        lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      }
      await _clearSession(
        notify: !silent,
        preserveError: !silent,
        preservedStatusCode: lastErrorStatusCode,
      );
      return false;
    } finally {
      if (!silent) {
        isAuthenticating = false;
        notifyListeners();
      }
    }
  }

  Future<bool> login({
    String? userId,
    String? password,
    bool silent = false,
  }) async {
    final nextUserId = (userId ?? Env.debugLoginUserId).trim();
    final nextPassword = password ?? Env.debugLoginPassword;

    if (nextUserId.isEmpty || nextPassword.isEmpty) {
      if (!silent) {
        error = 'Nhap user ID va mat khau de dang nhap';
        lastErrorStatusCode = null;
        notifyListeners();
      }
      return false;
    }

    if (!silent) {
      isAuthenticating = true;
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();
    }

    try {
      _tokens = await _authApi.login(
        userId: nextUserId,
        password: nextPassword,
      );

      currentUser = <String, dynamic>{'user_id': nextUserId};
      currentUser = await _authApi.me();
      return true;
    } catch (e) {
      await _clearSession(notify: false);
      if (!silent) {
        error = _friendlyError(e, fallback: 'Dang nhap that bai');
        lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      }
      return false;
    } finally {
      if (!silent) {
        isAuthenticating = false;
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    await _authApi.logout();
    _tokens = null;
    currentUser = null;
    error = null;
    lastErrorStatusCode = null;
    _client.clearAccessToken();
    notifyListeners();
  }

  Future<String?> _refreshAccessToken() async {
    final currentRefreshToken = refreshToken?.trim() ?? '';
    if (currentRefreshToken.isEmpty) {
      return null;
    }

    try {
      _tokens = await _authApi.refreshSession(
        refreshToken: currentRefreshToken,
      );
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();
      return _tokens?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleUnauthorized() async {
    await _clearSession(notify: true);
  }

  Future<void> _clearSession({
    required bool notify,
    bool preserveError = false,
    int? preservedStatusCode,
  }) async {
    final previousError = error;
    _tokens = null;
    currentUser = null;
    error = preserveError ? previousError : null;
    lastErrorStatusCode = preserveError ? preservedStatusCode : null;
    _client.clearAccessToken();
    await _authApi.clearPersistedSession();
    if (notify) {
      notifyListeners();
    }
  }

  String _friendlyError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.statusCode == 401) {
        return 'Phien dang nhap khong hop le hoac da het han';
      }
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong co quyen truy cap';
      }
      if (e.statusCode == 429) {
        return 'Dang bi gioi han request, vui long thu lai sau';
      }
      return e.message;
    }
    return fallback;
  }
}
