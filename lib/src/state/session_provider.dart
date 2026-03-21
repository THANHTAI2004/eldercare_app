import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/current_user.dart';
import 'package:eldercare_app/src/domain/models/register_request.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider({required ApiClient client, required AuthApiService authApi})
    : _client = client,
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
  bool isRegistering = false;
  bool isUpdatingProfile = false;
  bool isChangingPassword = false;

  AuthTokens? _tokens;
  CurrentUser? currentUser;
  String? error;
  int? lastErrorStatusCode;

  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;
  bool get isAuthenticated =>
      accessToken != null && accessToken!.trim().isNotEmpty;

  String get authenticatedUserId {
    return currentUser?.userId.trim() ?? '';
  }

  String get authenticatedRole => currentUser?.role.trim().toLowerCase() ?? '';
  String get authenticatedPhoneNumber => currentUser?.phoneNumber.trim() ?? '';

  Future<void> bootstrap() {
    return _bootstrapFuture ??= _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    isBootstrapping = true;
    notifyListeners();

    try {
      await restoreSession(silent: true);
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
      final savedCurrentUser = await _authApi.loadSavedCurrentUser();
      currentUser = savedCurrentUser == null
          ? null
          : CurrentUser.fromJson(savedCurrentUser);

      if (_tokens == null || _tokens!.accessToken.isEmpty) {
        return false;
      }

      currentUser = CurrentUser.fromJson(await _authApi.me());
      return true;
    } catch (e) {
      if (!silent) {
        error = _friendlyError(e, fallback: AppStrings.sessionRestoreFailed);
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
    String? phoneNumber,
    String? password,
    bool silent = false,
  }) async {
    final loginPhoneCandidates = AppValidators.loginPhoneCandidates(
      phoneNumber,
    );
    final nextPhoneNumber = loginPhoneCandidates.isEmpty
        ? AppValidators.normalizePhoneNumber(phoneNumber)
        : loginPhoneCandidates.first;
    final nextPassword = password ?? '';

    if (nextPhoneNumber.isEmpty || nextPassword.isEmpty) {
      if (!silent) {
        error = AppStrings.loginCredentialsRequired;
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
      for (var i = 0; i < loginPhoneCandidates.length; i++) {
        final candidate = loginPhoneCandidates[i];
        try {
          _tokens = await _authApi.login(
            phoneNumber: candidate,
            password: nextPassword,
          );
          currentUser = CurrentUser.fromJson(await _authApi.me());
          return true;
        } catch (e, st) {
          final isLastCandidate = i == loginPhoneCandidates.length - 1;
          final canRetryWithAlternatePhone =
              e is ApiRequestException &&
              e.statusCode == 401 &&
              !isLastCandidate;

          if (canRetryWithAlternatePhone) {
            continue;
          }
          Error.throwWithStackTrace(e, st);
        }
      }

      throw StateError('Login flow ended without a result');
    } catch (e) {
      await _clearSession(notify: false);
      if (!silent) {
        error = _friendlyLoginError(e, fallback: AppStrings.loginFailed);
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

  Future<bool> register({
    required String name,
    required String phoneNumber,
    required String dateOfBirth,
    required String password,
  }) async {
    isRegistering = true;
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      await _authApi.register(
        RegisterRequest(
          name: name.trim(),
          phoneNumber: AppValidators.normalizePhoneNumber(phoneNumber),
          dateOfBirth: dateOfBirth.trim(),
          password: password,
        ),
      );
      return true;
    } catch (e) {
      error = _friendlyRegisterError(e, fallback: AppStrings.registerFailed);
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      return false;
    } finally {
      isRegistering = false;
      notifyListeners();
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

  Future<bool> updateProfile({
    required String name,
    required String dateOfBirth,
  }) async {
    isUpdatingProfile = true;
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      final json = await _authApi.updateProfile(
        name: name,
        dateOfBirth: dateOfBirth,
      );
      currentUser = CurrentUser.fromJson(json);
      return true;
    } catch (e) {
      error = _friendlyError(
        e,
        fallback: 'Không thể cập nhật thông tin tài khoản',
      );
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      return false;
    } finally {
      isUpdatingProfile = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isChangingPassword = true;
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      await _authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      error = _friendlyChangePasswordError(
        e,
        fallback: 'Không thể đổi mật khẩu',
      );
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      return false;
    } finally {
      isChangingPassword = false;
      notifyListeners();
    }
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
    error = AppStrings.sessionExpired;
    lastErrorStatusCode = 401;
    await _clearSession(
      notify: true,
      preserveError: true,
      preservedStatusCode: 401,
    );
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
        return AppStrings.sessionExpired;
      }
      if (e.statusCode == 403) {
        return AppStrings.permissionDenied;
      }
      if (e.statusCode == 405) {
        return 'Máy chủ chưa hỗ trợ chức năng này.';
      }
      if (e.statusCode == 429) {
        return AppStrings.rateLimited;
      }
      return e.message;
    }
    return fallback;
  }

  String _friendlyLoginError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.statusCode == 401) {
        return AppStrings.loginUnauthorized;
      }
      if (e.statusCode == 422) {
        return AppStrings.loginInvalid;
      }
      if (e.statusCode == 500) {
        return AppStrings.serverError;
      }
      return _friendlyError(e, fallback: fallback);
    }
    return fallback;
  }

  String _friendlyRegisterError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.statusCode == 409) {
        return AppStrings.registerPhoneTaken;
      }
      if (e.statusCode == 422) {
        final message = e.message.toLowerCase();
        if (message.contains('birth') || message.contains('date')) {
          return AppStrings.invalidBirthDate;
        }
        if (message.contains('password')) {
          return AppStrings.passwordTooShort;
        }
        return AppStrings.registerInvalidData;
      }
      if (e.statusCode == 500) {
        return AppStrings.serverError;
      }
      return e.message;
    }
    return fallback;
  }

  String _friendlyChangePasswordError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      final message = e.message.toLowerCase();
      if (e.statusCode == 401 &&
          message.contains('current password is incorrect')) {
        return 'Mật khẩu hiện tại không đúng';
      }
      if (e.statusCode == 400 && message.contains('different')) {
        return 'Mật khẩu mới phải khác mật khẩu hiện tại';
      }
    }
    return _friendlyError(e, fallback: fallback);
  }
}
