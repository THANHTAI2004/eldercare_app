import 'dart:convert';

class Device {
  Device({
    required this.id,
    required this.name,
  });

  /// userId của ESP (lấy từ QR)
  final String id;
  /// Tên hiển thị trong app
  String name;

  /// Tạo Device từ nội dung QR
  /// - Nếu QR là JSON: {"userId":"u01","name":"Chest 01"}
  /// - Nếu QR chỉ là "u01" thì dùng làm id luôn
  factory Device.fromQr(String qrRaw) {
    String id;
    String name;

    final text = qrRaw.trim();
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final uid = (data['userId'] ?? data['id'])?.toString();
      if (uid == null || uid.isEmpty) {
        throw const FormatException('userId missing');
      }
      id = uid;
      name = (data['name'] ?? 'Thiết bị $id').toString();
    } catch (_) {
      // QR chỉ chứa userId thuần
      id = text;
      name = 'Thiết bị $id';
    }

    return Device(id: id, name: name);
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: (json['name'] ?? json['id']).toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}
