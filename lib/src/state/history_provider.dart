import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/vitals_cache_storage.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';

class HistoryProvider extends ChangeNotifier {
  factory HistoryProvider({
    ApiClient? client,
    HealthApiService? api,
    VitalsCacheStorage? cacheStorage,
  }) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return HistoryProvider._(
      api: api ?? HealthApiService(client: resolvedClient),
      cacheStorage: cacheStorage ?? VitalsCacheStorage(),
    );
  }

  HistoryProvider._({
    required HealthApiService api,
    required VitalsCacheStorage cacheStorage,
  }) : _api = api,
       _cacheStorage = cacheStorage;

  final HealthApiService _api;
  final VitalsCacheStorage _cacheStorage;

  String _authenticatedUserId = '';
  bool _isAuthenticated = false;

  String userId = '';
  String deviceId = '';
  DateTime selectedDayLocal = _todayLocal();

  AsyncStatus status = AsyncStatus.idle;
  String? error;
  int? lastErrorStatusCode;
  bool isShowingCachedHistory = false;

  final List<VitalPoint> _points = <VitalPoint>[];
  List<VitalPoint> get points => List.unmodifiable(_points);

  bool get isAuthenticated => _isAuthenticated;
  bool get hasNoDataError => lastErrorStatusCode == 404;

  void handleSessionState({
    required bool isAuthenticated,
    required String authenticatedUserId,
  }) {
    final authChanged =
        _isAuthenticated != isAuthenticated ||
        _authenticatedUserId != authenticatedUserId;
    if (!authChanged) return;

    final previousUserId = _authenticatedUserId;
    _isAuthenticated = isAuthenticated;
    _authenticatedUserId = authenticatedUserId.trim();

    if (!_isAuthenticated ||
        (previousUserId.isNotEmpty && previousUserId != _authenticatedUserId)) {
      _reset();
    }

    if (_isAuthenticated && userId.isEmpty && _authenticatedUserId.isNotEmpty) {
      userId = _authenticatedUserId;
    }

    notifyListeners();
  }

  Future<void> bindScope({
    String? userId,
    String? deviceId,
    DateTime? dayLocal,
    bool load = false,
  }) async {
    final nextUserId = userId?.trim();
    final nextDeviceId = deviceId?.trim();
    final scopeChanged =
        (nextUserId != null && nextUserId != this.userId) ||
        (nextDeviceId != null && nextDeviceId != this.deviceId);
    if (dayLocal != null) {
      selectedDayLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    }

    if (nextUserId != null) {
      if (!_canAccessUserId(nextUserId, candidateDeviceId: nextDeviceId)) {
        status = AsyncStatus.error;
        error = _userScopeError();
        lastErrorStatusCode = 403;
        notifyListeners();
        return;
      }
      this.userId = nextUserId;
    }
    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
    }

    if (this.userId.isEmpty && _authenticatedUserId.isNotEmpty) {
      this.userId = _authenticatedUserId;
    }

    if (scopeChanged) {
      _points.clear();
      status = AsyncStatus.idle;
      error = null;
      lastErrorStatusCode = null;
      isShowingCachedHistory = false;
      await _restoreCachedHistoryIfAvailable();
    }

    if (load) {
      await loadForSelectedDay();
      return;
    }
    notifyListeners();
  }

  Future<void> loadForDay(DateTime dayLocal, {int limit = 1000}) async {
    selectedDayLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);

    if (!_isAuthenticated) {
      _points.clear();
      status = AsyncStatus.unauthorized;
      error = 'Phien dang nhap khong hop le hoac da het han';
      lastErrorStatusCode = 401;
      isShowingCachedHistory = false;
      notifyListeners();
      return;
    }

    if (userId.isEmpty && deviceId.isEmpty) {
      _points.clear();
      status = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      isShowingCachedHistory = false;
      notifyListeners();
      return;
    }

    try {
      status = AsyncStatus.loading;
      error = null;
      lastErrorStatusCode = null;
      isShowingCachedHistory = false;
      notifyListeners();

      final loaded = deviceId.isNotEmpty
          ? await _api.getHistoryByDevice(deviceId: deviceId, limit: limit)
          : await _api.getVitalsByUser(
              userId: userId,
              deviceId: deviceId,
              limit: limit,
            );
      loaded.sort((a, b) => a.time.compareTo(b.time));

      _points
        ..clear()
        ..addAll(loaded);
      await _cacheStorage.saveHistory(scopeKey: _scopeKey, points: _points);

      final selectedPoints = pointsForLocalDay(selectedDayLocal);
      status = selectedPoints.isEmpty ? AsyncStatus.empty : AsyncStatus.success;
    } catch (e) {
      _points.clear();
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      if (lastErrorStatusCode == 401) {
        status = AsyncStatus.unauthorized;
        error = 'Phien dang nhap khong hop le hoac da het han';
      } else if (lastErrorStatusCode == 404) {
        status = AsyncStatus.empty;
        error = null;
        isShowingCachedHistory = false;
      } else {
        final cached = await _cacheStorage.loadHistory(scopeKey: _scopeKey);
        if (cached.isNotEmpty) {
          _points
            ..clear()
            ..addAll(cached);
          isShowingCachedHistory = true;
          status = pointsForLocalDay(selectedDayLocal).isEmpty
              ? AsyncStatus.empty
              : AsyncStatus.success;
          error = _staleMessage(e);
        } else {
          status = AsyncStatus.error;
          error = _friendlyError(e, fallback: 'Khong tai duoc lich su');
          isShowingCachedHistory = false;
        }
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadForSelectedDay() {
    return loadForDay(selectedDayLocal);
  }

  List<VitalPoint> pointsForLocalDay(DateTime dayLocal) {
    return _points
        .where((p) {
          final t = p.time.toLocal();
          return t.year == dayLocal.year &&
              t.month == dayLocal.month &&
              t.day == dayLocal.day;
        })
        .toList(growable: false);
  }

  List<VitalPoint> metricPointsForSelectedDay(Metric metric) {
    final selectedPoints = pointsForLocalDay(selectedDayLocal)
        .where((e) {
          final value = e.valueOf(metric);
          return value != null && value.isFinite;
        })
        .toList(growable: false);
    selectedPoints.sort((a, b) => a.time.compareTo(b.time));
    return selectedPoints;
  }

  void _reset() {
    userId = '';
    deviceId = '';
    status = AsyncStatus.idle;
    error = null;
    lastErrorStatusCode = null;
    isShowingCachedHistory = false;
    _points.clear();
    selectedDayLocal = _todayLocal();
  }

  bool _canAccessUserId(String candidateUserId, {String? candidateDeviceId}) {
    if ((candidateDeviceId?.trim().isNotEmpty ?? false)) {
      return true;
    }
    final trimmed = candidateUserId.trim();
    if (!_isUserScopedSession) return true;
    return trimmed.isEmpty || trimmed == _authenticatedUserId;
  }

  bool get _isUserScopedSession =>
      _isAuthenticated && _authenticatedUserId.isNotEmpty;

  String _userScopeError() {
    return 'Tai khoan hien tai chi duoc xem du lieu cua $_authenticatedUserId';
  }

  Future<void> _restoreCachedHistoryIfAvailable() async {
    if (userId.isEmpty && deviceId.isEmpty) return;
    final cached = await _cacheStorage.loadHistory(scopeKey: _scopeKey);
    if (cached.isEmpty) return;
    _points
      ..clear()
      ..addAll(cached);
    isShowingCachedHistory = true;
    status = pointsForLocalDay(selectedDayLocal).isEmpty
        ? AsyncStatus.empty
        : AsyncStatus.success;
    notifyListeners();
  }

  String get _scopeKey =>
      _cacheStorage.scopeKey(userId: userId, deviceId: deviceId);

  String _staleMessage(Object e) {
    if (e is ApiRequestException && e.isNetworkError) {
      return 'Dang hien thi lich su luu tam vi khong ket noi duoc toi server';
    }
    return 'Dang hien thi lich su luu tam gan nhat';
  }

  String _friendlyError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.isNetworkError) {
        return 'Khong the ket noi den server';
      }
      if (e.statusCode == 401) {
        return 'Phien dang nhap khong hop le hoac da het han';
      }
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong co quyen truy cap du lieu nay';
      }
      if (e.statusCode == 404) return 'Khong tim thay du lieu tren server';
      if (e.statusCode == 429) {
        return 'Dang bi gioi han request, vui long thu lai sau';
      }
      return e.message;
    }
    return fallback;
  }
}

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
