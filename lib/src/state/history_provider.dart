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

  String _sessionIdentity = '';
  bool _isAuthenticated = false;

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
    final nextSessionIdentity = authenticatedUserId.trim();
    final authChanged =
        _isAuthenticated != isAuthenticated ||
        _sessionIdentity != nextSessionIdentity;
    if (!authChanged) return;

    final previousSessionIdentity = _sessionIdentity;
    _isAuthenticated = isAuthenticated;
    _sessionIdentity = nextSessionIdentity;

    if (!_isAuthenticated ||
        (previousSessionIdentity.isNotEmpty &&
            previousSessionIdentity != _sessionIdentity)) {
      _reset();
    }

    notifyListeners();
  }

  Future<void> bindScope({
    String? deviceId,
    DateTime? dayLocal,
    bool load = false,
  }) async {
    final nextDeviceId = deviceId?.trim();
    final scopeChanged =
        nextDeviceId != null && nextDeviceId != this.deviceId;
    if (dayLocal != null) {
      selectedDayLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    }

    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
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

    if (deviceId.isEmpty) {
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

      final loaded = await _api.getHistoryByDevice(
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
    deviceId = '';
    status = AsyncStatus.idle;
    error = null;
    lastErrorStatusCode = null;
    isShowingCachedHistory = false;
    _points.clear();
    selectedDayLocal = _todayLocal();
  }

  Future<void> _restoreCachedHistoryIfAvailable() async {
    if (deviceId.isEmpty) return;
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
      _cacheStorage.scopeKey(userId: '', deviceId: deviceId);

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
