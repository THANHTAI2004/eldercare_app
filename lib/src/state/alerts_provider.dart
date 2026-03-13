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
  String _userId = '';

  bool isLoading = false;
  bool isAcknowledging = false;
  String? error;
  int? lastErrorStatusCode;
  AlertSeverityFilter severityFilter = AlertSeverityFilter.all;
  AlertAckFilter ackFilter = AlertAckFilter.activeOnly;

  List<AlertItem> get items => List.unmodifiable(_items);

  List<AlertItem> get visibleItems {
    return _items
        .where((item) {
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
        })
        .toList(growable: false);
  }

  int get activeCount => _items.where((item) => !item.acknowledged).length;

  void handleSessionState({
    required bool isAuthenticated,
    required String authenticatedUserId,
  }) {
    if (!isAuthenticated || authenticatedUserId.trim().isEmpty) {
      _userId = '';
      _items.clear();
      error = null;
      lastErrorStatusCode = null;
      notifyListeners();
      return;
    }

    final normalizedUserId = authenticatedUserId.trim();
    if (_userId == normalizedUserId) return;
    _userId = normalizedUserId;
    _items.clear();
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();
  }

  Future<void> loadAlerts() async {
    if (_userId.isEmpty) {
      _items.clear();
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      final alerts = await _api.getAlerts(userId: _userId);
      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items
        ..clear()
        ..addAll(alerts);
    } catch (e) {
      if (e is ApiRequestException) {
        error = _friendlyError(e);
        lastErrorStatusCode = e.statusCode;
      } else {
        error = 'Khong tai duoc danh sach canh bao';
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
        error = 'Khong the acknowledge canh bao';
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
      return 'Phien dang nhap khong hop le hoac da het han';
    }
    if (e.statusCode == 403) {
      return 'Tai khoan hien tai khong co quyen xem canh bao';
    }
    if (e.statusCode == 404) {
      return 'Chua co canh bao nao tren server';
    }
    if (e.statusCode == 429) {
      return 'Dang bi gioi han request, vui long thu lai sau';
    }
    return e.message;
  }
}
