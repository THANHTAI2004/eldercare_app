import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_thresholds_api_service.dart';
import 'package:eldercare_app/src/data/local/device_thresholds_storage.dart';
import 'package:eldercare_app/src/domain/models/device_thresholds.dart';

class DeviceThresholdsProvider extends ChangeNotifier {
  DeviceThresholdsProvider({
    DeviceThresholdsApiService? api,
    DeviceThresholdsStorage? storage,
  }) : _api = api ?? DeviceThresholdsApiService(),
       _storage = storage ?? DeviceThresholdsStorage();

  final DeviceThresholdsApiService _api;
  final DeviceThresholdsStorage _storage;

  String _sessionIdentity = '';
  String _deviceId = '';
  bool _isAuthenticated = false;
  bool _supportsRemoteLoad = true;

  DeviceThresholds? _thresholds;

  bool isLoading = false;
  bool isSaving = false;
  String? error;
  String? infoMessage;
  int? lastErrorStatusCode;

  DeviceThresholds? get thresholds => _thresholds;
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
      _thresholds = null;
      error = null;
      infoMessage = null;
      lastErrorStatusCode = null;
      _supportsRemoteLoad = true;
    }

    notifyListeners();
  }

  void bindDevice(String? deviceId) {
    final nextDeviceId = deviceId?.trim() ?? '';
    if (_deviceId == nextDeviceId) return;

    _deviceId = nextDeviceId;
    _thresholds = null;
    error = null;
    infoMessage = null;
    lastErrorStatusCode = null;
    notifyListeners();
  }

  Future<void> loadThresholds() async {
    if (!_isAuthenticated || _deviceId.isEmpty) {
      _thresholds = null;
      error = null;
      infoMessage = null;
      lastErrorStatusCode = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    infoMessage = null;
    lastErrorStatusCode = null;
    notifyListeners();

    final cached = await _storage.load(deviceId: _deviceId);
    if (cached != null) {
      _thresholds = cached;
      infoMessage = 'Dang tai gia tri moi nhat tu may chu...';
      notifyListeners();
    }

    try {
      if (!_supportsRemoteLoad) {
        _thresholds = cached;
        infoMessage = _cachedOnlyMessage(hasLocalValue: cached != null);
        return;
      }

      _thresholds = await _api.getDeviceThresholds(deviceId: _deviceId);
      infoMessage = null;
      if (_thresholds != null) {
        await _storage.save(deviceId: _deviceId, thresholds: _thresholds!);
      }
    } catch (e) {
      if (e is ApiRequestException) {
        lastErrorStatusCode = e.statusCode;
        if (_isRemoteReadUnsupported(e)) {
          _supportsRemoteLoad = false;
          _thresholds = cached;
          error = null;
          infoMessage = _cachedOnlyMessage(hasLocalValue: cached != null);
        } else if (cached != null &&
            (e.isNetworkError || (e.statusCode ?? 0) >= 500)) {
          _thresholds = cached;
          error = null;
          infoMessage =
              'Khong tai duoc nguong tu may chu. App dang hien thi gia tri luu gan nhat tren may nay.';
        } else {
          error = _friendlyError(e, isSavingAction: false);
          infoMessage = null;
        }
      } else if (cached != null) {
        _thresholds = cached;
        error = null;
        infoMessage =
            'Khong tai duoc nguong tu may chu. App dang hien thi gia tri luu gan nhat tren may nay.';
      } else {
        error = 'Khong tai duoc nguong canh bao cua thiet bi';
        infoMessage = null;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveThresholds(DeviceThresholds next) async {
    if (!_isAuthenticated || _deviceId.isEmpty) {
      error = 'Chua co thiet bi hop le de luu nguong canh bao';
      infoMessage = null;
      lastErrorStatusCode = null;
      notifyListeners();
      return false;
    }

    isSaving = true;
    error = null;
    infoMessage = null;
    lastErrorStatusCode = null;
    notifyListeners();

    try {
      _thresholds = await _api.updateDeviceThresholds(
        deviceId: _deviceId,
        payload: next.toPayload(),
      );
      if (_thresholds != null) {
        await _storage.save(deviceId: _deviceId, thresholds: _thresholds!);
      }
      if (!_supportsRemoteLoad) {
        infoMessage =
            'May chu hien chua ho tro tai lai nguong hien tai. App se dung gia tri vua luu tren may nay.';
      }
      return true;
    } catch (e) {
      if (e is ApiRequestException) {
        error = _friendlyError(e, isSavingAction: true);
        infoMessage = null;
        lastErrorStatusCode = e.statusCode;
      } else {
        error = 'Khong the luu nguong canh bao';
        infoMessage = null;
      }
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  bool _isRemoteReadUnsupported(ApiRequestException e) => e.statusCode == 405;

  String _cachedOnlyMessage({required bool hasLocalValue}) {
    if (hasLocalValue) {
      return 'May chu hien chua ho tro tai nguong hien tai. App dang hien thi gia tri luu gan nhat tren may nay.';
    }
    return 'May chu hien chua ho tro tai nguong hien tai. Hay nhap va luu nguong moi.';
  }

  String _friendlyError(ApiRequestException e, {required bool isSavingAction}) {
    if (e.statusCode == 401) {
      return 'Phien dang nhap khong hop le hoac da het han';
    }
    if (e.statusCode == 403) {
      return 'Chi chu thiet bi moi co the chinh sua nguong canh bao';
    }
    if (e.statusCode == 404) {
      return isSavingAction
          ? 'Khong tim thay thiet bi de cap nhat nguong canh bao'
          : 'Thiet bi nay chua co cau hinh nguong canh bao';
    }
    if (e.statusCode == 422) {
      return 'Gia tri nguong canh bao gui len chua dung dinh dang';
    }
    if (e.statusCode == 429) {
      return 'Dang bi gioi han yeu cau, vui long thu lai sau';
    }
    if (e.statusCode == 500) {
      return 'May chu dang gap loi, vui long thu lai sau';
    }
    return e.message;
  }
}
