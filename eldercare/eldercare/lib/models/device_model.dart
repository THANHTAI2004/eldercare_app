/// Device model
class DeviceModel {
  final String deviceUid;
  final String deviceType;
  final String? userId;
  final String? firmwareVersion;
  final String? macAddress;
  final int? batteryLevel;
  final DateTime? lastSeen;
  final bool isOnline;

  DeviceModel({
    required this.deviceUid,
    required this.deviceType,
    this.userId,
    this.firmwareVersion,
    this.macAddress,
    this.batteryLevel,
    this.lastSeen,
    this.isOnline = false,
  });

  // Convenience getter for backward compatibility
  String get deviceId => deviceUid;

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceUid: json['device_uid'] as String,
      deviceType: json['device_type'] as String,
      userId: json['user_id'] as String?,
      firmwareVersion: json['firmware_version'] as String?,
      macAddress: json['mac_address'] as String?,
      batteryLevel: json['battery_level'] as int?,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_uid': deviceUid,
      'device_type': deviceType,
      if (userId != null) 'user_id': userId,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      if (macAddress != null) 'mac_address': macAddress,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (lastSeen != null) 'last_seen': lastSeen!.toIso8601String(),
      'is_online': isOnline,
    };
  }

  /// Get battery status color
  String get batteryStatus {
    if (batteryLevel == null) return 'unknown';
    if (batteryLevel! > 50) return 'good';
    if (batteryLevel! > 20) return 'medium';
    return 'low';
  }

  /// Check if device is chest or wrist type
  bool get isChestDevice => deviceType.toLowerCase() == 'chest';
  bool get isWristDevice => deviceType.toLowerCase() == 'wrist';
}
