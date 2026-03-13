import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/config/env.dart';
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

  bool isSyncing = false;
  String? error;

  List<Device> get devices => List.unmodifiable(_devices);
  Device? get current => _current;

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
    notifyListeners();

    try {
      final remoteDevices = await _api.getMyDevices();
      final merged = _mergePreservingLocalNames(remoteDevices);

      _devices
        ..clear()
        ..addAll(merged);

      if (_devices.isEmpty) {
        _applyDevFallbackIfNeeded();
      }

      _selectCurrent(preferredUserId: authenticatedUserId);
      await _save();
    } catch (e) {
      error = e is ApiRequestException
          ? e.message
          : 'Khong tai duoc danh sach thiet bi';

      if (_devices.isEmpty) {
        _applyDevFallbackIfNeeded();
        await _save();
      }
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> ensureDevFallback() async {
    await load();
    if (_devices.isNotEmpty) return;

    final fallback = _buildDevFallback();
    if (fallback == null) return;

    _devices.add(fallback);
    _current = fallback;
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _devices.clear();
    _current = null;
    error = null;

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

  void _applyDevFallbackIfNeeded() {
    final fallback = _buildDevFallback();
    if (fallback == null) return;

    _devices
      ..clear()
      ..add(fallback);
    _current = fallback;
  }

  Device? _buildDevFallback() {
    if (!kDebugMode) return null;

    final fallbackUserId = Env.defaultUserId.trim();
    final fallbackDeviceId = Env.defaultDeviceId.trim();
    final resolvedDeviceId = fallbackDeviceId.isNotEmpty
        ? fallbackDeviceId
        : fallbackUserId;

    if (resolvedDeviceId.isEmpty) return null;

    final linkedUsers = fallbackUserId.isEmpty
        ? const <DeviceLinkedUser>[]
        : <DeviceLinkedUser>[
            DeviceLinkedUser(
              id: fallbackUserId,
              name: fallbackUserId,
              role: 'dev',
            ),
          ];

    return Device(
      id: resolvedDeviceId,
      name: 'Dev fallback $resolvedDeviceId',
      legacyUserId: fallbackUserId.isEmpty ? null : fallbackUserId,
      linkedUsers: linkedUsers,
      isLocalOnly: true,
    );
  }

  void _selectCurrent({required String preferredUserId}) {
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

    if (preferredUserId.trim().isNotEmpty) {
      for (final device in _devices) {
        if (device.primaryUserId == preferredUserId) {
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
              (remoteName.isEmpty ||
                  remoteName == remote.id ||
                  existing.isLocalOnly);

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
      linkedUsers: next.linkedUsers.isEmpty
          ? existing.linkedUsers
          : next.linkedUsers,
      legacyUserId: next.legacyUserId ?? existing.legacyUserId,
      isLocalOnly: next.isLocalOnly,
    );
  }
}
