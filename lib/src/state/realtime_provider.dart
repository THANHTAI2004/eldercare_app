import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/data/local/vitals_cache_storage.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';

class RealtimeProvider extends ChangeNotifier {
  factory RealtimeProvider({
    ApiClient? client,
    HealthApiService? api,
    VitalsCacheStorage? cacheStorage,
  }) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return RealtimeProvider._(
      api: api ?? HealthApiService(client: resolvedClient),
      cacheStorage: cacheStorage ?? VitalsCacheStorage(),
    );
  }

  RealtimeProvider._({
    required HealthApiService api,
    required VitalsCacheStorage cacheStorage,
  }) : _api = api,
       _cacheStorage = cacheStorage;

  final HealthApiService _api;
  final VitalsCacheStorage _cacheStorage;

  String _sessionIdentity = '';
  bool _isAuthenticated = false;
  bool _initialized = false;

  String deviceId = '';

  AsyncStatus latestStatus = AsyncStatus.idle;
  String? error;
  int? lastErrorStatusCode;
  VitalPoint? latest;
  bool isShowingCachedLatest = false;

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
        isShowingCachedLatest = false;
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
      isShowingCachedLatest = false;
      _resetSeen();
      notifyListeners();
      return;
    }

    await _restoreCachedLatestIfAvailable();
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
      isShowingCachedLatest = false;
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
    isShowingCachedLatest = false;
    _resetSeen();
    notifyListeners();

    await _restoreCachedLatestIfAvailable();
    await refreshLatest();
  }

  Future<void> refreshLatest({bool silent = false}) async {
    if (!hasDevice) {
      latest = null;
      latestStatus = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      isShowingCachedLatest = false;
      _resetSeen();
      notifyListeners();
      return;
    }

    if (!isAuthenticated) {
      latest = null;
      latestStatus = AsyncStatus.unauthorized;
      error = 'Phien dang nhap khong hop le hoac da het han';
      lastErrorStatusCode = 401;
      isShowingCachedLatest = false;
      _resetSeen();
      notifyListeners();
      return;
    }

    try {
      if (!silent) {
        latestStatus = AsyncStatus.loading;
        error = null;
        lastErrorStatusCode = null;
        isShowingCachedLatest = false;
        notifyListeners();
      }

      final point = await _api.getLatestByDevice(deviceId: deviceId);
      final isNew = latest == null || latest!.time != point.time;

      latest = point;
      latestStatus = AsyncStatus.success;
      isShowingCachedLatest = false;
      _markSeen(point.time);
      await _cacheStorage.saveLatest(scopeKey: _scopeKey, point: point);

      if (isNew) {
        _appendLivePoint(point);
      }
    } catch (e) {
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      if (lastErrorStatusCode == 401) {
        latestStatus = AsyncStatus.unauthorized;
        error = 'Phien dang nhap khong hop le hoac da het han';
      } else if (lastErrorStatusCode == 404) {
        latestStatus = AsyncStatus.empty;
        error = null;
        isShowingCachedLatest = false;
      } else {
        final cached = await _cacheStorage.loadLatest(scopeKey: _scopeKey);
        if (cached != null) {
          latest = cached;
          latestStatus = AsyncStatus.success;
          isShowingCachedLatest = true;
          _markSeen(cached.time);
          error = _staleMessage(e);
        } else {
          latestStatus = AsyncStatus.error;
          error = _friendlyError(
            e,
            fallback: 'Khong tai duoc du lieu moi nhat',
          );
          isShowingCachedLatest = false;
        }
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
    isShowingCachedLatest = false;
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

  Future<void> _restoreCachedLatestIfAvailable() async {
    if (!hasDevice) return;
    final cached = await _cacheStorage.loadLatest(scopeKey: _scopeKey);
    if (cached == null) return;
    latest = cached;
    latestStatus = AsyncStatus.success;
    isShowingCachedLatest = true;
    _markSeen(cached.time);
    notifyListeners();
  }

  String get _scopeKey =>
      _cacheStorage.scopeKey(userId: '', deviceId: deviceId);

  String _staleMessage(Object e) {
    if (e is ApiRequestException && e.isNetworkError) {
      return 'Dang hien thi du lieu luu tam vi khong ket noi duoc toi server';
    }
    return 'Dang hien thi du lieu luu tam gan nhat';
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
      if (e.statusCode == 422) return 'Du lieu gui len chua dung dinh dang';
      if (e.statusCode == 429) {
        return 'Dang bi gioi han request, vui long thu lai sau';
      }
      return e.message;
    }
    return fallback;
  }
}
