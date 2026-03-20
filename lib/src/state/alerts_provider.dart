import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/data/api/alerts_api_service.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/alert_item.dart';

enum AlertSeverityFilter { all, highOnly }

enum AlertAckFilter { all, activeOnly, acknowledgedOnly }

class AlertsProvider extends ChangeNotifier {
  AlertsProvider({AlertsApiService? api}) : _api = api ?? AlertsApiService();

  final AlertsApiService _api;

  final List<AlertItem> _items = <AlertItem>[];
  String _sessionIdentity = '';
  String _deviceId = '';
  bool _isAuthenticated = false;

  bool isLoading = false;
  bool isAcknowledging = false;
  String? error;
  int? lastErrorStatusCode;
  AlertSeverityFilter severityFilter = AlertSeverityFilter.all;
  AlertAckFilter ackFilter = AlertAckFilter.activeOnly;

  List<AlertItem> get items => List.unmodifiable(_items);

  List<AlertItem> get visibleItems {
    return _items.where((item) {
      if (severityFilter == AlertSeverityFilter.highOnly &&
          !item.isHighSeverity) {
        return false;
      }

      switch (ackFilter) {
        case AlertAckFilter.all:
          return true;
        case AlertAckFilter.activeOnly:
          return !item.acknowledged;
        case AlertAckFilter.acknowledgedOnly:
          return item.acknowledged;
      }
    }).toList(growable: false);
  }

  int get activeCount => _items.where((item) => !item.acknowledged).length;
  String get deviceId => _deviceId;
  bool get isAuthenticated => _isAuthenticated;

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
      _deviceId = '';
      _items.clear();
      error = null;
      lastErrorStatusCode = null;
    }

    notifyListeners();
  }

  void bindDevice(String? deviceId) {
    final nextDeviceId = deviceId?.trim() ?? '';
    if (_deviceId == nextDeviceId) return;

    _deviceId = nextDeviceId;
    _items.clear();
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();
  }

  Future<void> loadAlerts() async {
    if (!_isAuthenticated || _deviceId.isEmpty) {
      _items.clear();
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      final alerts = await _api.getAlertsByDevice(deviceId: _deviceId);
      final scopedAlerts = alerts
          .where((item) => (item.deviceId?.trim() ?? '') == _deviceId)
          .toList(growable: false);
      scopedAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items
        ..clear()
        ..addAll(scopedAlerts);
    } catch (e) {
      if (e is ApiRequestException) {
        error = _friendlyError(e);
        lastErrorStatusCode = e.statusCode;
      } else {
        error = 'Không tải được danh sách cảnh báo';
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acknowledge(String alertId) async {
    if (alertId.trim().isEmpty) return;

    isAcknowledging = true;
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      await _api.acknowledgeAlert(alertId: alertId);
      final index = _items.indexWhere((item) => item.id == alertId);
      if (index >= 0) {
        final current = _items[index];
        _items[index] = AlertItem(
          id: current.id,
          title: current.title,
          message: current.message,
          severity: current.severity,
          createdAt: current.createdAt,
          acknowledged: true,
          acknowledgedAt: DateTime.now().toUtc(),
          userId: current.userId,
          deviceId: current.deviceId,
        );
      }
    } catch (e) {
      if (e is ApiRequestException) {
        error = _friendlyError(e);
        lastErrorStatusCode = e.statusCode;
      } else {
        error = 'Không thể đánh dấu đã xử lý cảnh báo';
      }
    } finally {
      isAcknowledging = false;
      notifyListeners();
    }
  }

  void setSeverityFilter(AlertSeverityFilter value) {
    severityFilter = value;
    notifyListeners();
  }

  void setAckFilter(AlertAckFilter value) {
    ackFilter = value;
    notifyListeners();
  }

  String _friendlyError(ApiRequestException e) {
    if (e.statusCode == 401) {
      return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
    }
    if (e.statusCode == 403) {
      return 'Tài khoản hiện tại không có quyền xem cảnh báo của thiết bị này';
    }
    if (e.statusCode == 404) {
      return 'Chưa có cảnh báo nào cho thiết bị này';
    }
    if (e.statusCode == 422) {
      return 'Yêu cầu tải cảnh báo chưa đúng định dạng';
    }
    if (e.statusCode == 429) {
      return 'Đang bị giới hạn yêu cầu, vui lòng thử lại sau';
    }
    if (e.statusCode == 500) {
      return 'Máy chủ đang gặp lỗi, vui lòng thử lại sau';
    }
    return e.message;
  }
}
