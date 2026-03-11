import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class RealtimeProvider extends ChangeNotifier {
  final _api = HealthApiService();

  String userId = Env.defaultUserId;
  String deviceId = Env.defaultDeviceId;

  bool get hasUser => userId.isNotEmpty;
  bool get hasDevice => deviceId.isNotEmpty;

  bool _initialized = false;
  bool isLoadingLatest = false;
  bool isLoadingHistory = false;
  bool isRequestingEcg = false;

  String? error;

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

  void _appendLivePoint(VitalPoint point) {
    _livePoints.add(point);
    if (_livePoints.length > AppConstants.liveMaxPoints) {
      _livePoints.removeRange(0, _livePoints.length - AppConstants.liveMaxPoints);
    }
  }

  Future<void> init({String? userId, String? deviceId}) async {
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
      this.userId = nextUserId;
    }
    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
    }

    if (!hasUser) {
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = null;
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

  Future<bool> checkUserExists(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return false;

    try {
      await _api.getLatestByUser(userId: trimmed);
      return true;
    } catch (_) {
      try {
        final points = await _api.getVitalsByUser(userId: trimmed, limit: 1);
        return points.isNotEmpty;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('checkUserExists error: $e');
        }
        return false;
      }
    }
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
      if (e.statusCode == 401) return 'API key khong hop le hoac bi thieu';
      if (e.statusCode == 404) return 'Khong tim thay du lieu tren server';
      if (e.statusCode == 422) return 'Du lieu gui len chua dung dinh dang';
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
