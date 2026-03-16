import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class RealtimeProvider extends ChangeNotifier {
  factory RealtimeProvider({ApiClient? client}) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return RealtimeProvider._(
      api: HealthApiService(client: resolvedClient),
    );
  }

  RealtimeProvider._({required HealthApiService api}) : _api = api;

  final HealthApiService _api;

  String _authenticatedUserId = '';
  String _authenticatedRole = '';
  bool _isAuthenticated = false;
  bool _initialized = false;

  String userId = '';
  String deviceId = '';

  bool get hasUser => userId.isNotEmpty;
  bool get hasDevice => deviceId.isNotEmpty;
  bool get isAuthenticated => _isAuthenticated;
  String get authenticatedUserId => _authenticatedUserId;
  String get authenticatedRole => _authenticatedRole;
  bool get isUserScopedSession =>
      _isAuthenticated &&
      _authenticatedUserId.isNotEmpty &&
      _authenticatedRole != 'admin' &&
      _authenticatedRole != 'caregiver';

  bool isLoadingLatest = false;
  bool isLoadingHistory = false;
  bool isRequestingEcg = false;

  String? error;
  int? lastErrorStatusCode;
  String? ecgStatusMessage;

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

  bool get hasSessionExpiredError => lastErrorStatusCode == 401;
  bool get hasPermissionError => lastErrorStatusCode == 403;
  bool get hasNoDataError => lastErrorStatusCode == 404;
  bool get isRateLimited => lastErrorStatusCode == 429;

  void handleSessionState({
    required bool isAuthenticated,
    required String authenticatedUserId,
    required String authenticatedRole,
  }) {
    final authChanged =
        _isAuthenticated != isAuthenticated ||
        _authenticatedUserId != authenticatedUserId ||
        _authenticatedRole != authenticatedRole;

    if (!authChanged) return;

    final previousUserId = _authenticatedUserId;
    _isAuthenticated = isAuthenticated;
    _authenticatedUserId = authenticatedUserId.trim();
    _authenticatedRole = authenticatedRole.trim().toLowerCase();

    final shouldResetData =
        !_isAuthenticated ||
        (previousUserId.isNotEmpty && previousUserId != _authenticatedUserId);
    if (shouldResetData) {
      _clearRealtimeState();
    }

    if (_isAuthenticated && userId.isEmpty && _authenticatedUserId.isNotEmpty) {
      userId = _authenticatedUserId;
    }

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

  void _markSeen([DateTime? time]) {
    _lastSeenUtc = (time ?? DateTime.now()).toUtc();
  }

  void _resetSeen() {
    _lastSeenUtc = null;
  }

  void _clearRealtimeState() {
    _initialized = false;
    userId = '';
    deviceId = '';
    latest = null;
    error = null;
    lastErrorStatusCode = null;
    ecgStatusMessage = null;
    _livePoints.clear();
    _historyPoints.clear();
    _resetSeen();
  }

  bool _canAccessUserId(String candidateUserId) {
    final trimmed = candidateUserId.trim();
    if (!isUserScopedSession) return true;
    return trimmed.isEmpty || trimmed == authenticatedUserId;
  }

  String _userScopeError() {
    return 'Tai khoan hien tai chi duoc xem du lieu cua $authenticatedUserId';
  }

  Future<void> init({String? userId, String? deviceId}) async {
    final nextUserId = userId?.trim();
    final nextDeviceId = deviceId?.trim();

    if (_initialized) {
      if (nextUserId != null && nextUserId != this.userId) {
        await changeUser(nextUserId, deviceId: nextDeviceId);
      } else if (nextDeviceId != null && nextDeviceId != this.deviceId) {
        await changeUser(this.userId, deviceId: nextDeviceId);
      } else if (hasUser || hasDevice) {
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
        lastErrorStatusCode = 403;
        _resetSeen();
        notifyListeners();
        return;
      }
      this.userId = nextUserId;
    }
    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
    }

    if (!hasUser && authenticatedUserId.isNotEmpty) {
      this.userId = authenticatedUserId;
    }

    if (!isAuthenticated) {
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = 'Chua dang nhap vao server';
      lastErrorStatusCode = 401;
      _resetSeen();
      notifyListeners();
      return;
    }

    if (!hasUser && !hasDevice) {
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = null;
      lastErrorStatusCode = null;
      _resetSeen();
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
      lastErrorStatusCode = 403;
      notifyListeners();
      return;
    }

    userId = newUserId;
    if (newDeviceId != null) {
      this.deviceId = newDeviceId;
    }

    latest = null;
    _livePoints.clear();
    _historyPoints.clear();
    error = null;
    lastErrorStatusCode = null;
    _resetSeen();
    notifyListeners();

    if (!isAuthenticated) {
      error = 'Phien dang nhap khong hop le hoac da het han';
      lastErrorStatusCode = 401;
      notifyListeners();
      return;
    }

    await refreshLatest();
    await loadHistory(limit: 500);
  }

  Future<void> refreshLatest({bool silent = false}) async {
    if (!hasUser && !hasDevice) {
      latest = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    if (!isAuthenticated) {
      latest = null;
      _resetSeen();
      if (!silent) {
        error = 'Phien dang nhap khong hop le hoac da het han';
        lastErrorStatusCode = 401;
      }
      notifyListeners();
      return;
    }

    try {
      if (!silent) {
        isLoadingLatest = true;
        error = null;
        lastErrorStatusCode = null;
        notifyListeners();
      }

      final p = hasDevice
          ? await _api.getLatestByDevice(deviceId: deviceId)
          : await _api.getLatestByUser(userId: userId, deviceId: deviceId);
      final isNew = latest == null || latest!.time != p.time;

      latest = p;
      _markSeen(p.time);

      if (isNew) {
        _appendLivePoint(p);
      }
    } catch (e) {
      if (!silent) {
        error = _friendlyError(e, fallback: 'Khong tai duoc du lieu moi nhat');
        lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
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
    if (!hasUser && !hasDevice) {
      _historyPoints.clear();
      notifyListeners();
      return;
    }

    if (!isAuthenticated) {
      _historyPoints.clear();
      error = 'Phien dang nhap khong hop le hoac da het han';
      lastErrorStatusCode = 401;
      notifyListeners();
      return;
    }

    try {
      isLoadingHistory = true;
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();

      final points = hasDevice
          ? await _api.getHistoryByDevice(deviceId: deviceId, limit: limit)
          : await _api.getVitalsByUser(
              userId: userId,
              deviceId: deviceId,
              limit: limit,
            );
      points.sort((a, b) => a.time.compareTo(b.time));

      _historyPoints
        ..clear()
        ..addAll(points);
    } catch (e) {
      error = _friendlyError(e, fallback: 'Khong tai duoc lich su');
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
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
    if (!isAuthenticated) return;
    await refreshLatest();
  }

  Future<Map<String, dynamic>> requestEcg({
    int durationSeconds = 10,
    int samplingRate = 250,
  }) async {
    if (!hasDevice) {
      throw StateError('Device ID is empty');
    }

    if (!isAuthenticated) {
      throw StateError('Phien dang nhap khong hop le hoac da het han');
    }

    isRequestingEcg = true;
    error = null;
    lastErrorStatusCode = null;
    ecgStatusMessage = 'Da gui lenh ECG, dang cho ket qua moi...';
    notifyListeners();

    try {
      final requestStartedAt = DateTime.now().toUtc();
      final req = await _api.requestEcg(
        deviceId: deviceId,
        durationSeconds: durationSeconds,
        samplingRate: samplingRate,
      );

      final ecgResult = await _api.waitForEcgResult(
        deviceId: deviceId,
        pollIntervalMs: Env.pollIntervalMs,
        notBefore: requestStartedAt,
      );

      await refreshLatest();
      final output = <String, dynamic>{...req};
      if (ecgResult != null) {
        output['ecg_result'] = ecgResult;
        ecgStatusMessage = 'Da nhan duoc ket qua ECG moi cho device hien tai.';
      } else {
        output['message'] =
            'Da gui lenh ECG nhung chua co ket qua moi trong thoi gian cho.';
        ecgStatusMessage = output['message']?.toString();
      }
      return output;
    } catch (e) {
      error = _friendlyError(e, fallback: 'Yeu cau ECG that bai');
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      ecgStatusMessage = null;
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
