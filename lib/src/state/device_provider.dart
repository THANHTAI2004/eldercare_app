import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider({DeviceApiService? api}) : _api = api ?? DeviceApiService();

  static const _devicesKey = 'devices';
  static const _currentIdKey = 'current_device_id';

  final DeviceApiService _api;
  final List<Device> _devices = <Device>[];
  Device? _current;
  bool _loaded = false;
  String _sessionUserId = '';
  Future<void>? _sessionSyncFuture;

  bool isSyncing = false;
  String? error;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DeviceProvider] $message');
    }
  }

  List<Device> get devices => List.unmodifiable(_devices);
  Device? get current => _current;

  Device? findById(String? id) {
    final normalizedId = id?.trim() ?? '';
    if (normalizedId.isEmpty) return null;

    for (final device in _devices) {
      if (device.id == normalizedId ||
          device.resolvedDeviceId == normalizedId) {
        return device;
      }
    }
    return null;
  }

  Future<void> handleSessionState({
    required bool isAuthenticated,
    required String authenticatedUserId,
  }) {
    return _sessionSyncFuture ??=
        _handleSessionState(
          isAuthenticated: isAuthenticated,
          authenticatedUserId: authenticatedUserId,
        ).whenComplete(() {
          _sessionSyncFuture = null;
        });
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _loadFromStorage();
    notifyListeners();
  }

  Future<void> syncFromServer({required String authenticatedUserId}) async {
    await load();

    isSyncing = true;
    error = null;
    _log('Syncing /api/v1/me/devices for user=$authenticatedUserId');
    notifyListeners();

    try {
      final remoteDevices = await _api.getMyDevices();
      final merged = _mergePreservingLocalNames(remoteDevices);

      _devices
        ..clear()
        ..addAll(merged);

      _selectCurrent();
      _log(
        'Device sync completed: total=${_devices.length}, current=${_current?.id ?? 'none'}',
      );
      await _save();
    } catch (e) {
      error = e is ApiRequestException
          ? e.message
          : 'Không tải được danh sách thiết bị';
      _log('Device sync failed: $error');
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _devices.clear();
    _current = null;
    error = null;
    _sessionUserId = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_devicesKey);
    await prefs.remove(_currentIdKey);

    notifyListeners();
  }

  Future<void> addFromQr(String qrRaw) async {
    await load();
    final next = Device.fromQr(qrRaw);
    _upsert(next);
    _current = next;
    await _save();
    notifyListeners();
  }

  Future<void> rename(String id, String newName) async {
    await load();
    final normalizedName = newName.trim();
    if (normalizedName.isEmpty) return;

    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) return;

    final existing = _devices[index];
    _devices[index] = existing.copyWith(name: normalizedName);
    if (_current?.id == id) {
      _current = _devices[index];
    }

    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await load();
    if (_devices.isEmpty) return;

    _devices.removeWhere((device) => device.id == id);
    if (_devices.isEmpty) {
      _current = null;
    } else if (_current?.id == id) {
      _current = _devices.first;
    }

    await _save();
    notifyListeners();
  }

  Future<void> setCurrent(String id) async {
    await load();
    if (_devices.isEmpty) {
      _current = null;
      await _save();
      notifyListeners();
      return;
    }

    final selected = _devices.firstWhere(
      (device) => device.id == id,
      orElse: () => _devices.first,
    );
    _current = selected;
    _log('Current device changed to ${selected.id}');

    await _save();
    notifyListeners();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_devicesKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _devices
          ..clear()
          ..addAll(
            list.whereType<Map>().map(
              (entry) => Device.fromJson(Map<String, dynamic>.from(entry)),
            ),
          );
      } catch (_) {
        _devices.clear();
      }
    } else {
      _devices.clear();
    }

    if (_devices.isEmpty) {
      _current = null;
      return;
    }

    final currentId = prefs.getString(_currentIdKey);
    if (currentId == null || currentId.trim().isEmpty) {
      _current = _devices.first;
      return;
    }

    _current = _devices.firstWhere(
      (device) => device.id == currentId,
      orElse: () => _devices.first,
    );
  }

  Future<void> _handleSessionState({
    required bool isAuthenticated,
    required String authenticatedUserId,
  }) async {
    await load();

    if (!isAuthenticated || authenticatedUserId.trim().isEmpty) {
      _sessionUserId = '';
      _log('Session cleared');
      return;
    }

    final normalizedUserId = authenticatedUserId.trim();
    if (_sessionUserId == normalizedUserId &&
        _devices.isNotEmpty) {
      return;
    }

    _sessionUserId = normalizedUserId;
    _log('Session ready for user=$normalizedUserId, starting device sync');
    await syncFromServer(authenticatedUserId: normalizedUserId);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    if (_devices.isEmpty) {
      await prefs.remove(_devicesKey);
      await prefs.remove(_currentIdKey);
      return;
    }

    await prefs.setString(
      _devicesKey,
      jsonEncode(_devices.map((device) => device.toJson()).toList()),
    );
    await prefs.setString(_currentIdKey, _current?.id ?? _devices.first.id);
  }

  void _selectCurrent() {
    if (_devices.isEmpty) {
      _current = null;
      return;
    }

    final currentId = _current?.id;
    if (currentId != null) {
      for (final device in _devices) {
        if (device.id == currentId) {
          _current = device;
          return;
        }
      }
    }

    _current = _devices.first;
  }

  List<Device> _mergePreservingLocalNames(List<Device> remoteDevices) {
    final existingById = <String, Device>{
      for (final device in _devices) device.id: device,
    };

    return remoteDevices
        .map((remote) {
          final existing = existingById[remote.id];
          if (existing == null) return remote;

          final existingName = existing.name.trim();
          final remoteName = remote.name.trim();
          final shouldKeepExistingName =
              existingName.isNotEmpty &&
              (remoteName.isEmpty || remoteName == remote.id);

          return remote.copyWith(
            name: shouldKeepExistingName ? existingName : remote.name,
          );
        })
        .toList(growable: false);
  }

  void _upsert(Device next) {
    final index = _devices.indexWhere((device) => device.id == next.id);
    if (index < 0) {
      _devices.add(next);
      return;
    }

    final existing = _devices[index];
    _devices[index] = next.copyWith(
      name: next.name.trim().isEmpty ? existing.name : next.name,
      linkRole: next.linkRole ?? existing.linkRole,
      linkedUsers: next.linkedUsers.isEmpty
          ? existing.linkedUsers
          : next.linkedUsers,
      legacyUserId: next.legacyUserId ?? existing.legacyUserId,
      isLocalOnly: next.isLocalOnly,
    );
  }
}
