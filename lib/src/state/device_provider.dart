import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/domain/models/device.dart';

class DeviceProvider extends ChangeNotifier {
  static const _devicesKey = 'devices';
  static const _currentIdKey = 'current_device_id';

  final List<Device> _devices = [];
  Device? _current;
  bool _loaded = false;

  List<Device> get devices => List.unmodifiable(_devices);
  Device? get current => _current;

  /// Load danh sách thiết bị + current từ SharedPreferences (chỉ 1 lần)
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString(_devicesKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _devices
          ..clear()
          ..addAll(
            list.map((e) => Device.fromJson(e as Map<String, dynamic>)),
          );
      } catch (_) {
        _devices.clear();
      }
    } else {
      _devices.clear();
    }

    if (_devices.isEmpty) {
      _current = null;
    } else {
      final currentId = prefs.getString(_currentIdKey);
      if (currentId != null) {
        _current = _devices.firstWhere(
              (d) => d.id == currentId,
          orElse: () => _devices.first,
        );
      } else {
        _current = _devices.first;
      }
    }

    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    if (_devices.isEmpty) {
      await prefs.remove(_devicesKey);
      await prefs.remove(_currentIdKey);
      return;
    }

    final list = _devices.map((d) => d.toJson()).toList();
    await prefs.setString(_devicesKey, jsonEncode(list));
    await prefs.setString(_currentIdKey, _current?.id ?? _devices.first.id);
  }

  /// Thêm / cập nhật thiết bị từ QR hoặc userId
  Future<void> addFromQr(String qrRaw) async {
    final dev = Device.fromQr(qrRaw);

    final idx = _devices.indexWhere((d) => d.id == dev.id);
    if (idx >= 0) {
      // đã tồn tại → cập nhật name
      _devices[idx].name = dev.name;
      _current = _devices[idx];
    } else {
      // thêm mới
      _devices.add(dev);
      _current = dev;
    }

    await _save();
    notifyListeners();
  }

  Future<void> rename(String id, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;

    final d = _devices.firstWhere(
          (e) => e.id == id,
      orElse: () => _current ?? (throw StateError('No devices')),
    );
    d.name = name;

    await _save();
    notifyListeners();
  }

  /// Xoá thiết bị – cho phép xoá hết (không giữ device mặc định)
  Future<void> remove(String id) async {
    if (_devices.isEmpty) return;

    _devices.removeWhere((d) => d.id == id);

    if (_devices.isEmpty) {
      _current = null;
    } else if (_current?.id == id) {
      _current = _devices.first;
    }

    await _save();
    notifyListeners();
  }

  /// Chọn thiết bị hiện tại
  Future<void> setCurrent(String id) async {
    if (_devices.isEmpty) {
      _current = null;
      await _save();
      notifyListeners();
      return;
    }

    final d = _devices.firstWhere(
          (e) => e.id == id,
      orElse: () => _devices.first,
    );
    _current = d;

    await _save();
    notifyListeners();
  }
}
