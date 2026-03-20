class AlertItem {
  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.acknowledged,
    this.acknowledgedAt,
    this.userId,
    this.deviceId,
  });

  final String id;
  final String title;
  final String message;
  final String severity;
  final DateTime createdAt;
  final bool acknowledged;
  final DateTime? acknowledgedAt;
  final String? userId;
  final String? deviceId;

  bool get isHighSeverity {
    final normalized = severity.trim().toLowerCase();
    return normalized == 'high' || normalized == 'critical';
  }

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    final id =
        _readString(json['alert_id']) ??
        _readString(json['alertId']) ??
        _readString(json['id']) ??
        '';
    final title =
        _readString(json['title']) ??
        _readString(json['name']) ??
        _readString(json['type']) ??
        'Cảnh báo';
    final message =
        _readString(json['message']) ??
        _readString(json['description']) ??
        _readString(json['detail']) ??
        title;
    final severity =
        _readString(json['severity']) ??
        _readString(json['level']) ??
        'unknown';
    final createdAt =
        _readTime(json['created_at']) ??
        _readTime(json['createdAt']) ??
        _readTime(json['timestamp']) ??
        _readTime(json['ts']) ??
        DateTime.now().toUtc();
    final acknowledged =
        json['acknowledged'] == true ||
        json['is_acknowledged'] == true ||
        json['isAcknowledged'] == true ||
        _readTime(json['acknowledged_at']) != null;
    final acknowledgedAt =
        _readTime(json['acknowledged_at']) ?? _readTime(json['acknowledgedAt']);

    return AlertItem(
      id: id,
      title: title,
      message: message,
      severity: severity,
      createdAt: createdAt,
      acknowledged: acknowledged,
      acknowledgedAt: acknowledgedAt,
      userId: _readString(json['user_id']) ?? _readString(json['userId']),
      deviceId: _readString(json['device_id']) ?? _readString(json['deviceId']),
    );
  }
}

String? _readString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

DateTime? _readTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc();
}
