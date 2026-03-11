import 'dart:convert';

class Device {
  Device({
    required this.id,
    required this.name,
    this.deviceId,
  });

  /// userId cua nguoi dung duoc theo doi
  final String id;

  /// deviceId cua ESP (can cho ECG request), neu null thi fallback = id
  final String? deviceId;

  /// Ten hien thi trong app
  String name;

  String get resolvedDeviceId {
    final d = deviceId?.trim();
    if (d == null || d.isEmpty) return id;
    return d;
  }

  /// Tao Device tu noi dung QR.
  /// - JSON: {"userId":"u01","deviceId":"dev-esp-001","name":"Chest 01"}
  /// - Chuoi thuong: "u01"
  factory Device.fromQr(String qrRaw) {
    String id;
    String? deviceId;
    String name;

    final text = qrRaw.trim();
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final uid = (data['userId'] ?? data['user_id'] ?? data['uid'])?.toString();
      final did = (data['deviceId'] ?? data['device_id'] ?? data['id'])?.toString();

      if (uid == null || uid.trim().isEmpty) {
        throw const FormatException('userId missing');
      }

      id = uid.trim();
      deviceId = did?.trim();
      name = (data['name'] ?? 'Thiet bi $id').toString();
    } catch (_) {
      id = text;
      name = 'Thiet bi $id';
    }

    return Device(id: id, name: name, deviceId: deviceId);
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: (json['name'] ?? json['id']).toString(),
      deviceId: json['deviceId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (deviceId != null && deviceId!.trim().isNotEmpty) 'deviceId': deviceId,
      };
}
