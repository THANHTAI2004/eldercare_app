import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/state/async_status.dart';

class EcgProvider extends ChangeNotifier {
  factory EcgProvider({ApiClient? client, HealthApiService? api}) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return EcgProvider._(api: api ?? HealthApiService(client: resolvedClient));
  }

  EcgProvider._({required HealthApiService api}) : _api = api;

  final HealthApiService _api;

  String _sessionIdentity = '';
  bool _isAuthenticated = false;

  String deviceId = '';

  AsyncStatus status = AsyncStatus.idle;
  String? message;
  String? error;
  int? lastErrorStatusCode;
  EcgReading? latest;

  DateTime selectedHistoryDayLocal = _todayLocal();
  AsyncStatus historyStatus = AsyncStatus.idle;
  String? historyError;
  int? historyLastErrorStatusCode;

  final List<EcgReading> _historyReadings = <EcgReading>[];
  List<EcgReading> get historyReadings => List.unmodifiable(_historyReadings);

  bool get isLoading => status.isLoading;
  bool get hasData => latest != null;
  bool get isLoadingHistory => historyStatus.isLoading;
  bool get hasNoHistoryDataError => historyLastErrorStatusCode == 404;

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

  void bindScope({String? deviceId}) {
    final nextDeviceId = deviceId?.trim();
    final scopeChanged = nextDeviceId != null && nextDeviceId != this.deviceId;
    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
    }
    if (scopeChanged) {
      _resetDeviceScopedState();
    }
    notifyListeners();
  }

  Future<void> refreshLatest({bool silent = false}) async {
    if (!_isAuthenticated) {
      status = AsyncStatus.unauthorized;
      error = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      lastErrorStatusCode = 401;
      latest = null;
      notifyListeners();
      return;
    }

    if (deviceId.trim().isEmpty) {
      status = AsyncStatus.empty;
      error = null;
      lastErrorStatusCode = null;
      latest = null;
      notifyListeners();
      return;
    }

    try {
      if (!silent) {
        status = AsyncStatus.loading;
        error = null;
        lastErrorStatusCode = null;
        message = null;
        notifyListeners();
      }

      final reading = await _api.getLatestEcgByDevice(deviceId: deviceId);
      latest = reading;
      if (reading == null || !reading.hasWaveform) {
        status = AsyncStatus.empty;
      } else {
        status = AsyncStatus.success;
      }
    } catch (e) {
      latest = null;
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      if (lastErrorStatusCode == 401) {
        status = AsyncStatus.unauthorized;
        error = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      } else if (lastErrorStatusCode == 404) {
        status = AsyncStatus.empty;
        error = null;
      } else {
        status = AsyncStatus.error;
        error = _friendlyError(e, fallback: 'Không tải được dữ liệu ECG');
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadHistoryForDay(DateTime dayLocal, {int limit = 100}) async {
    selectedHistoryDayLocal = DateTime(
      dayLocal.year,
      dayLocal.month,
      dayLocal.day,
    );

    if (!_isAuthenticated) {
      _historyReadings.clear();
      historyStatus = AsyncStatus.unauthorized;
      historyError = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      historyLastErrorStatusCode = 401;
      notifyListeners();
      return;
    }

    if (deviceId.trim().isEmpty) {
      _historyReadings.clear();
      historyStatus = AsyncStatus.empty;
      historyError = null;
      historyLastErrorStatusCode = null;
      notifyListeners();
      return;
    }

    try {
      historyStatus = AsyncStatus.loading;
      historyError = null;
      historyLastErrorStatusCode = null;
      notifyListeners();

      final readings = await _api.getEcgReadingsByDevice(
        deviceId: deviceId,
        limit: limit,
      );
      readings.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

      final filtered = readings
          .where((reading) {
            final localTime = reading.recordedAt.toLocal();
            return localTime.year == selectedHistoryDayLocal.year &&
                localTime.month == selectedHistoryDayLocal.month &&
                localTime.day == selectedHistoryDayLocal.day;
          })
          .toList(growable: false);

      _historyReadings
        ..clear()
        ..addAll(filtered);

      historyStatus = filtered.isEmpty
          ? AsyncStatus.empty
          : AsyncStatus.success;
    } catch (e) {
      _historyReadings.clear();
      historyLastErrorStatusCode = e is ApiRequestException
          ? e.statusCode
          : null;
      if (historyLastErrorStatusCode == 401) {
        historyStatus = AsyncStatus.unauthorized;
        historyError = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      } else if (historyLastErrorStatusCode == 404) {
        historyStatus = AsyncStatus.empty;
        historyError = null;
      } else {
        historyStatus = AsyncStatus.error;
        historyError = _friendlyError(
          e,
          fallback: 'Không tải được lịch sử ECG',
        );
      }
    } finally {
      notifyListeners();
    }
  }

  void clearMessage() {
    message = null;
    if (status == AsyncStatus.success || status == AsyncStatus.empty) {
      status = AsyncStatus.idle;
    }
    notifyListeners();
  }

  void _resetDeviceScopedState() {
    status = AsyncStatus.idle;
    message = null;
    error = null;
    lastErrorStatusCode = null;
    latest = null;

    selectedHistoryDayLocal = _todayLocal();
    historyStatus = AsyncStatus.idle;
    historyError = null;
    historyLastErrorStatusCode = null;
    _historyReadings.clear();
  }

  void _reset() {
    deviceId = '';
    _resetDeviceScopedState();
  }

  String _friendlyError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.statusCode == 401) {
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
      }
      if (e.statusCode == 403) {
        return 'Tài khoản hiện tại không có quyền xem ECG';
      }
      if (e.statusCode == 429) {
        return 'Đang bị giới hạn yêu cầu, vui lòng thử lại sau';
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
