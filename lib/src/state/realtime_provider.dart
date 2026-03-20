import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';

class RealtimeProvider extends ChangeNotifier {
  factory RealtimeProvider({ApiClient? client, HealthApiService? api}) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return RealtimeProvider._(
      api: api ?? HealthApiService(client: resolvedClient),
    );
  }

  RealtimeProvider._({required HealthApiService api}) : _api = api;

  final HealthApiService _api;

  String _sessionIdentity = '';
  bool _isAuthenticated = false;
  bool _initialized = false;

  String deviceId = '';

  AsyncStatus latestStatus = AsyncStatus.idle;
  String? error;
  int? lastErrorStatusCode;
  VitalPoint? latest;

  final List<VitalPoint> _livePoints = <VitalPoint>[];
  List<VitalPoint> get livePoints => List.unmodifiable(_livePoints);

  DateTime? _lastSeenUtc;
  DateTime? get lastSeen => _lastSeenUtc?.toLocal();

  final Duration onlineThreshold = const Duration(seconds: 20);

  bool get hasDevice => deviceId.isNotEmpty;
  bool get isAuthenticated => _isAuthenticated;

  bool get isOnline {
    final t = _lastSeenUtc;
    if (t == null) return false;
    return DateTime.now().toUtc().difference(t) <= onlineThreshold;
  }

  String get lastSeenText {
    final t = _lastSeenUtc;
    if (t == null) return 'Chưa có dữ liệu';
    final diff = DateTime.now().toUtc().difference(t);

    if (diff.inSeconds < 5) return 'Vừa xong';
    if (diff.inSeconds < 60) return '${diff.inSeconds} giây trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    return '${diff.inHours} giờ trước';
  }

  bool get hasSessionExpiredError => lastErrorStatusCode == 401;
  bool get hasPermissionError => lastErrorStatusCode == 403;
  bool get hasNoDataError => lastErrorStatusCode == 404;
  bool get isLoadingLatest => latestStatus.isLoading;

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

    final shouldResetData =
        !_isAuthenticated ||
        (previousSessionIdentity.isNotEmpty &&
            previousSessionIdentity != _sessionIdentity);
    if (shouldResetData) {
      _clearLatestState();
    }

    notifyListeners();
  }

  Future<void> init({String? deviceId}) async {
    final nextDeviceId = deviceId?.trim() ?? '';

    if (_initialized) {
      if (nextDeviceId != this.deviceId) {
        await changeDevice(nextDeviceId);
      } else if (hasDevice) {
        await refreshLatest();
      } else {
        latest = null;
        latestStatus = AsyncStatus.empty;
        error = null;
        lastErrorStatusCode = null;
        _resetSeen();
        notifyListeners();
      }
      return;
    }
    _initialized = true;

    this.deviceId = nextDeviceId;
    if (!hasDevice) {
      latest = null;
      latestStatus = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    await refreshLatest();
  }

  Future<void> changeDevice(String newDeviceId) async {
    final nextDeviceId = newDeviceId.trim();

    if (nextDeviceId.isEmpty) {
      deviceId = '';
      latest = null;
      _livePoints.clear();
      latestStatus = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    deviceId = nextDeviceId;
    latest = null;
    _livePoints.clear();
    latestStatus = AsyncStatus.idle;
    error = null;
    lastErrorStatusCode = null;
    _resetSeen();
    notifyListeners();

    await refreshLatest();
  }

  Future<void> refreshLatest({bool silent = false}) async {
    if (!hasDevice) {
      latest = null;
      latestStatus = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    if (!isAuthenticated) {
      latest = null;
      latestStatus = AsyncStatus.unauthorized;
      error = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      lastErrorStatusCode = 401;
      _resetSeen();
      notifyListeners();
      return;
    }

    try {
      if (!silent) {
        latestStatus = AsyncStatus.loading;
        error = null;
        lastErrorStatusCode = null;
        notifyListeners();
      }

      final point = await _api.getLatestByDevice(deviceId: deviceId);
      final isNew = latest == null || latest!.time != point.time;

      latest = point;
      latestStatus = AsyncStatus.success;
      _markSeen(point.time);

      if (isNew) {
        _appendLivePoint(point);
      }
    } catch (e) {
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      if (lastErrorStatusCode == 401) {
        latestStatus = AsyncStatus.unauthorized;
        error = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      } else if (lastErrorStatusCode == 404) {
        latest = null;
        latestStatus = AsyncStatus.empty;
        error = null;
        _resetSeen();
      } else {
        latestStatus = AsyncStatus.error;
        error = _friendlyError(
          e,
          fallback: 'Không tải được dữ liệu mới nhất',
        );
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> reconnectApi() async {
    if (!isAuthenticated) return;
    await refreshLatest();
  }

  List<VitalPoint> liveSeriesFor(Metric metric) {
    return _livePoints.where((p) => p.valueOf(metric) != null).toList();
  }

  Future<bool> checkServer() async {
    try {
      final res = await _api.health();
      return res['status']?.toString().toLowerCase() == 'ok';
    } catch (_) {
      return false;
    }
  }

  void _clearLatestState() {
    _initialized = false;
    deviceId = '';
    latest = null;
    error = null;
    lastErrorStatusCode = null;
    latestStatus = AsyncStatus.idle;
    _livePoints.clear();
    _resetSeen();
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
      if (e.statusCode == 422) return 'Dữ liệu gửi lên chưa đúng định dạng';
      if (e.statusCode == 429) {
        return 'Hệ thống đang giới hạn tần suất, vui lòng thử lại sau';
      }
      return e.message;
    }
    return fallback;
  }
}
