import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/health_api_service.dart';
import 'package:eldercare_app/src/state/async_status.dart';

class EcgProvider extends ChangeNotifier {
  factory EcgProvider({ApiClient? client, HealthApiService? api}) {
    final resolvedClient = client ?? ApiClient.fromEnv();
    return EcgProvider._(
      api: api ?? HealthApiService(client: resolvedClient),
    );
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
  Map<String, dynamic>? lastResult;

  bool get isLoading => status.isLoading;

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
    final scopeChanged =
        nextDeviceId != null && nextDeviceId != this.deviceId;
    if (nextDeviceId != null) {
      this.deviceId = nextDeviceId;
    }
    if (scopeChanged) {
      status = AsyncStatus.idle;
      message = null;
      error = null;
      lastErrorStatusCode = null;
      lastResult = null;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestEcg({
    int durationSeconds = 10,
    int samplingRate = 250,
  }) async {
    if (!_isAuthenticated) {
      status = AsyncStatus.unauthorized;
      error = 'Phien dang nhap khong hop le hoac da het han';
      lastErrorStatusCode = 401;
      notifyListeners();
      throw StateError(error!);
    }

    if (deviceId.trim().isEmpty) {
      status = AsyncStatus.error;
      error = 'Device ID is empty';
      lastErrorStatusCode = null;
      notifyListeners();
      throw StateError(error!);
    }

    status = AsyncStatus.loading;
    error = null;
    lastErrorStatusCode = null;
    message = 'Da gui lenh ECG, dang cho ket qua moi...';
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

      lastResult = <String, dynamic>{...req};
      if (ecgResult != null) {
        lastResult!['ecg_result'] = ecgResult;
        status = AsyncStatus.success;
        message = 'Da nhan duoc ket qua ECG moi cho device hien tai.';
      } else {
        status = AsyncStatus.empty;
        message =
            'Da gui lenh ECG nhung chua co ket qua moi trong thoi gian cho.';
      }
      return lastResult!;
    } catch (e) {
      lastErrorStatusCode = e is ApiRequestException ? e.statusCode : null;
      if (lastErrorStatusCode == 401) {
        status = AsyncStatus.unauthorized;
        error = 'Phien dang nhap khong hop le hoac da het han';
      } else {
        status = AsyncStatus.error;
        error = _friendlyError(e, fallback: 'Yeu cau ECG that bai');
      }
      message = null;
      notifyListeners();
      rethrow;
    } finally {
      if (!status.isError && !status.isUnauthorized) {
        notifyListeners();
      }
    }
  }

  void clearMessage() {
    message = null;
    if (status == AsyncStatus.success || status == AsyncStatus.empty) {
      status = AsyncStatus.idle;
    }
    notifyListeners();
  }

  void _reset() {
    deviceId = '';
    status = AsyncStatus.idle;
    message = null;
    error = null;
    lastErrorStatusCode = null;
    lastResult = null;
  }

  String _friendlyError(Object e, {required String fallback}) {
    if (e is ApiRequestException) {
      if (e.statusCode == 401) {
        return 'Phien dang nhap khong hop le hoac da het han';
      }
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong co quyen yeu cau ECG';
      }
      if (e.statusCode == 409) {
        return 'Yeu cau dang cho xu ly, vui long thu lai sau';
      }
      if (e.statusCode == 429) {
        return 'Dang bi gioi han request, vui long thu lai sau';
      }
      return e.message;
    }
    return fallback;
  }
}
