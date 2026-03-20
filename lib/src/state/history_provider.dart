import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';

class HistoryProvider extends ChangeNotifier {
  factory HistoryProvider({ApiClient? client, HealthApiService? api}) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return HistoryProvider._(
      api: api ?? HealthApiService(client: resolvedClient),
    );
  }

  HistoryProvider._({required HealthApiService api}) : _api = api;

  final HealthApiService _api;

  String _sessionIdentity = '';
  bool _isAuthenticated = false;

  String deviceId = '';
  DateTime selectedDayLocal = _todayLocal();

  AsyncStatus status = AsyncStatus.idle;
  String? error;
  int? lastErrorStatusCode;

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
      error = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      lastErrorStatusCode = 401;
      notifyListeners();
      return;
    }

    if (deviceId.isEmpty) {
      _points.clear();
      status = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();
      return;
    }

    try {
      status = AsyncStatus.loading;
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();

      final loaded = await _api.getHistoryByDevice(
        deviceId: deviceId,
        limit: limit,
      );
      loaded.sort((a, b) => a.time.compareTo(b.time));

      _points
        ..clear()
        ..addAll(loaded);

      final selectedPoints = pointsForLocalDay(selectedDayLocal);
      status = selectedPoints.isEmpty ? AsyncStatus.empty : AsyncStatus.success;
    } catch (e) {
      _points.clear();
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      if (lastErrorStatusCode == 401) {
        status = AsyncStatus.unauthorized;
        error = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      } else if (lastErrorStatusCode == 404) {
        status = AsyncStatus.empty;
        error = null;
      } else {
        status = AsyncStatus.error;
        error = _friendlyError(e, fallback: 'Không tải được lịch sử');
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
    _points.clear();
    selectedDayLocal = _todayLocal();
  }

  String _friendlyError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.isNetworkError) {
        return 'Không thể kết nối đến máy chủ';
      }
      if (e.statusCode == 401) {
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      }
      if (e.statusCode == 403) {
        return 'Tài khoản hiện tại không có quyền xem dữ liệu này';
      }
      if (e.statusCode == 404) return 'Không tìm thấy dữ liệu trên máy chủ';
      if (e.statusCode == 429) {
        return 'Hệ thống đang giới hạn tần suất, vui lòng thử lại sau';
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
