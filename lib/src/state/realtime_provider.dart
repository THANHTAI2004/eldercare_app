import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class RealtimeProvider extends ChangeNotifier {
  factory RealtimeProvider({ApiClient? client, AuthStorage? authStorage}) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    final resolvedStorage = authStorage ?? AuthStorage();
    return RealtimeProvider._(
      client: resolvedClient,
      api: HealthApiService(client: resolvedClient),
      authApi: AuthApiService(client: resolvedClient, storage: resolvedStorage),
    );
  }

  RealtimeProvider._({
    required ApiClient client,
    required HealthApiService api,
    required AuthApiService authApi,
  }) : _client = client,
       _api = api,
       _authApi = authApi;

  final ApiClient _client;
  final HealthApiService _api;
  final AuthApiService _authApi;

  String userId = '';
  String deviceId = '';

  bool get hasUser => userId.isNotEmpty;
  bool get hasDevice => deviceId.isNotEmpty;
  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
  String get authenticatedUserId =>
      currentUser?['user_id']?.toString().trim() ?? '';
  String get authenticatedRole =>
      currentUser?['role']?.toString().trim().toLowerCase() ?? '';
  bool get isUserScopedSession =>
      isAuthenticated &&
      authenticatedUserId.isNotEmpty &&
      authenticatedRole != 'admin' &&
      authenticatedRole != 'caregiver';

  bool _initialized = false;
  Future<void>? _bootstrapFuture;
  bool isLoadingLatest = false;
  bool isLoadingHistory = false;
  bool isRequestingEcg = false;
  bool isAuthenticating = false;

  String? error;
  String? accessToken;
  Map<String, dynamic>? currentUser;

  VitalPoint? latest;
  Metric selectedMetric = Metric.hr;

  final List<VitalPoint> _livePoints = [];
  List<VitalPoint> get livePoints => List.unmodifiable(_livePoints);

  final List<VitalPoint> _historyPoints = [];
  List<VitalPoint> get historyPoints => List.unmodifiable(_historyPoints);

  DateTime? _lastSeenUtc;
  DateTime? get lastSeen => _lastSeenUtc?.toLocal();

  final Duration onlineThreshold = const Duration(seconds: 20);

  bool get isOnline {
    final t = _lastSeenUtc;
    if (t == null) return false;
    return DateTime.now().toUtc().difference(t) <= onlineThreshold;
  }

  String get lastSeenText {
    final t = _lastSeenUtc;
    if (t == null) return 'Chua co du lieu';
    final diff = DateTime.now().toUtc().difference(t);

    if (diff.inSeconds < 5) return 'Vua xong';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s truoc';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p truoc';
    return '${diff.inHours}h truoc';
  }

  void _markSeen([DateTime? time]) {
    _lastSeenUtc = (time ?? DateTime.now()).toUtc();
  }

  void _resetSeen() {
    _lastSeenUtc = null;
  }

  bool _canAccessUserId(String candidateUserId) {
    final trimmed = candidateUserId.trim();
    if (!isUserScopedSession) return true;
    return trimmed.isEmpty || trimmed == authenticatedUserId;
  }

  String _userScopeError() {
    return 'Tai khoan hien tai chi duoc xem du lieu cua $authenticatedUserId';
  }

  Future<void> bootstrap() {
    return _bootstrapFuture ??= _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    final restored = await restoreSession(silent: true);
    if (restored) return;

    if (Env.hasLoginCredentials) {
      await login(silent: true);
    } else {
      notifyListeners();
    }
  }

  Future<bool> restoreSession({bool silent = false}) async {
    if (!silent) {
      isAuthenticating = true;
      error = null;
      notifyListeners();
    }

    try {
      final token = await _authApi.restoreAccessToken();
      accessToken = token;
      currentUser = await _authApi.loadSavedCurrentUser();

      if (token == null || token.isEmpty) {
        return false;
      }

      try {
        currentUser = await _authApi.me();
      } catch (e) {
        if (e is ApiRequestException && e.statusCode == 401) {
          await _authApi.logout();
          accessToken = null;
          currentUser = null;
          return false;
        }

        if (!silent) {
          error = _friendlyError(
            e,
            fallback: 'Khong the khoi phuc phien dang nhap',
          );
        }
      }

      if (userId.isEmpty && authenticatedUserId.isNotEmpty) {
        userId = authenticatedUserId;
      }

      return true;
    } finally {
      if (!silent) {
        isAuthenticating = false;
        notifyListeners();
      }
    }
  }

  Future<bool> ensureAuthenticated({bool silent = true}) async {
    await bootstrap();
    if (isAuthenticated) return true;

    if (!Env.hasLoginCredentials) {
      if (!silent) {
        error = 'Chua cau hinh LOGIN_USER_ID va LOGIN_PASSWORD';
        notifyListeners();
      }
      return false;
    }

    return login(silent: silent);
  }

  Future<bool> login({
    String? userId,
    String? password,
    bool silent = false,
  }) async {
    final nextUserId = (userId ?? Env.loginUserId).trim();
    final nextPassword = password ?? Env.loginPassword;

    if (nextUserId.isEmpty || nextPassword.isEmpty) {
      if (!silent) {
        error = 'Chua cau hinh LOGIN_USER_ID va LOGIN_PASSWORD';
        notifyListeners();
      }
      return false;
    }

    if (!silent) {
      isAuthenticating = true;
      error = null;
      notifyListeners();
    }

    try {
      final session = await _authApi.login(
        userId: nextUserId,
        password: nextPassword,
      );

      accessToken = _client.accessToken;
      currentUser = <String, dynamic>{
        'user_id': session['user_id'],
        'role': session['role'],
      };
      await _authApi.saveCurrentUser(currentUser!);

      try {
        currentUser = await _authApi.me();
      } catch (e) {
        if (e is ApiRequestException && e.statusCode == 401) rethrow;
        if (kDebugMode) {
          debugPrint('login -> me warning: $e');
        }
      }

      if (this.userId.isEmpty && authenticatedUserId.isNotEmpty) {
        this.userId = authenticatedUserId;
      }

      return true;
    } catch (e) {
      accessToken = null;
      currentUser = null;
      await _authApi.logout();

      if (!silent) {
        error = _friendlyError(e, fallback: 'Dang nhap that bai');
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
    accessToken = null;
    currentUser = null;
    error = null;
    latest = null;
    _livePoints.clear();
    _historyPoints.clear();
    _resetSeen();
    notifyListeners();
  }

  void _appendLivePoint(VitalPoint point) {
    _livePoints.add(point);
    if (_livePoints.length > AppConstants.liveMaxPoints) {
      _livePoints.removeRange(
        0,
        _livePoints.length - AppConstants.liveMaxPoints,
      );
    }
  }

  Future<void> init({String? userId, String? deviceId}) async {
    await bootstrap();

    final nextUserId = userId?.trim();
    final nextDeviceId = deviceId?.trim();

    if (_initialized) {
      if (nextUserId != null && nextUserId != this.userId) {
        await changeUser(nextUserId, deviceId: nextDeviceId);
      } else if (hasUser) {
        await refreshLatest();
      }
      return;
    }
    _initialized = true;

    if (nextUserId != null) {
      if (!_canAccessUserId(nextUserId)) {
        latest = null;
        _livePoints.clear();
        _historyPoints.clear();
        error = _userScopeError();
        _resetSeen();
        notifyListeners();
        return;
      }
      this.userId = nextUserId;
    }
    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
    }

    if (!hasUser) {
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = isAuthenticated ? null : 'Chua dang nhap vao server';
      _resetSeen();
      notifyListeners();
      return;
    }

    final loggedIn = await ensureAuthenticated(silent: true);
    if (!loggedIn) {
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      _resetSeen();
      error ??= 'Phien dang nhap khong hop le hoac da het han';
      notifyListeners();
      return;
    }

    await refreshLatest();
    await loadHistory(limit: 500);
  }

  Future<void> changeUser(String newUserId, {String? deviceId}) async {
    newUserId = newUserId.trim();
    final newDeviceId = deviceId?.trim();

    if (newUserId.isEmpty) {
      userId = '';
      if (newDeviceId != null) {
        this.deviceId = newDeviceId;
      }

      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    if (!_canAccessUserId(newUserId)) {
      error = _userScopeError();
      notifyListeners();
      return;
    }

    userId = newUserId;
    if (newDeviceId != null && newDeviceId.isNotEmpty) {
      this.deviceId = newDeviceId;
    }

    latest = null;
    _livePoints.clear();
    _historyPoints.clear();
    error = null;
    _resetSeen();
    notifyListeners();

    final loggedIn = await ensureAuthenticated(silent: true);
    if (!loggedIn) {
      error ??= 'Phien dang nhap khong hop le hoac da het han';
      notifyListeners();
      return;
    }

    await refreshLatest();
    await loadHistory(limit: 500);
  }

  Future<void> refreshLatest({bool silent = false}) async {
    if (!hasUser) {
      latest = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    final loggedIn = await ensureAuthenticated(silent: silent);
    if (!loggedIn) {
      latest = null;
      _resetSeen();
      if (!silent) {
        error ??= 'Phien dang nhap khong hop le hoac da het han';
      }
      notifyListeners();
      return;
    }

    try {
      if (!silent) {
        isLoadingLatest = true;
        error = null;
        notifyListeners();
      }

      final p = await _api.getLatestByUser(userId: userId);
      final isNew = latest == null || latest!.time != p.time;

      latest = p;
      _markSeen(p.time);

      if (isNew) {
        _appendLivePoint(p);
      }
    } catch (e) {
      if (!silent) {
        error = _friendlyError(e, fallback: 'Khong tai duoc du lieu moi nhat');
      }
    } finally {
      if (!silent) {
        isLoadingLatest = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> loadHistory({
    String from = '',
    String to = '',
    String window = '',
    int limit = 500,
  }) async {
    if (!hasUser) {
      _historyPoints.clear();
      notifyListeners();
      return;
    }

    final loggedIn = await ensureAuthenticated(silent: false);
    if (!loggedIn) {
      _historyPoints.clear();
      error ??= 'Phien dang nhap khong hop le hoac da het han';
      notifyListeners();
      return;
    }

    try {
      isLoadingHistory = true;
      error = null;
      notifyListeners();

      final points = await _api.getVitalsByUser(userId: userId, limit: limit);
      points.sort((a, b) => a.time.compareTo(b.time));

      _historyPoints
        ..clear()
        ..addAll(points);
    } catch (e) {
      error = _friendlyError(e, fallback: 'Khong tai duoc lich su');
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadHistoryForLocalDay({
    required DateTime dayLocal,
    String window = '10m',
  }) async {
    await loadHistory(window: window, limit: 1000);
  }

  Future<void> reconnectApi() async {
    final loggedIn = await ensureAuthenticated(silent: false);
    if (!loggedIn) return;
    await refreshLatest();
  }

  Future<Map<String, dynamic>> requestEcg({
    int durationSeconds = 10,
    int samplingRate = 250,
  }) async {
    if (!hasUser) {
      throw StateError('User ID is empty');
    }
    if (!hasDevice) {
      throw StateError('Device ID is empty');
    }

    final loggedIn = await ensureAuthenticated(silent: false);
    if (!loggedIn) {
      throw StateError('Phien dang nhap khong hop le hoac da het han');
    }

    isRequestingEcg = true;
    error = null;
    notifyListeners();

    try {
      final req = await _api.requestEcg(
        deviceId: deviceId,
        userId: userId,
        durationSeconds: durationSeconds,
        samplingRate: samplingRate,
      );

      final ecgResult = await _api.waitForEcgResult(
        userId: userId,
        pollIntervalMs: Env.pollIntervalMs,
      );

      await refreshLatest();
      final output = <String, dynamic>{...req};
      if (ecgResult != null) {
        output['ecg_result'] = ecgResult;
      }
      return output;
    } catch (e) {
      error = _friendlyError(e, fallback: 'Yeu cau ECG that bai');
      rethrow;
    } finally {
      isRequestingEcg = false;
      notifyListeners();
    }
  }

  void setMetric(Metric metric) {
    selectedMetric = metric;
    notifyListeners();
  }

  List<VitalPoint> liveSeriesFor(Metric metric) {
    return _livePoints.where((p) => p.valueOf(metric) != null).toList();
  }

  List<VitalPoint> historyForLocalDay(DateTime dayLocal) {
    return _historyPoints.where((p) {
      final t = p.time.toLocal();
      return t.year == dayLocal.year &&
          t.month == dayLocal.month &&
          t.day == dayLocal.day;
    }).toList();
  }

  List<VitalPoint> historyForUtcDay(DateTime dayUtc) {
    final d = DateTime.utc(dayUtc.year, dayUtc.month, dayUtc.day);
    final next = d.add(const Duration(days: 1));
    return _historyPoints
        .where((p) => !p.time.isBefore(d) && p.time.isBefore(next))
        .toList();
  }

  Future<bool> checkServer() async {
    try {
      final res = await _api.health();
      return res['status']?.toString().toLowerCase() == 'ok';
    } catch (_) {
      return false;
    }
  }

  String _friendlyError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.statusCode == 401) {
        return 'Phien dang nhap khong hop le hoac da het han';
      }
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong co quyen truy cap du lieu nay';
      }
      if (e.statusCode == 404) return 'Khong tim thay du lieu tren server';
      if (e.statusCode == 422) return 'Du lieu gui len chua dung dinh dang';
      if (e.statusCode == 409) {
        return 'Yeu cau dang cho xu ly, vui long thu lai sau';
      }
      if (e.statusCode == 429) {
        final retry = e.retryAfterSeconds;
        if (retry != null && retry > 0) {
          return 'Qua gioi han request, vui long thu lai sau $retry giay';
        }
        return 'Qua gioi han request, vui long thu lai sau';
      }
      return e.message;
    }
    return fallback;
  }
}
