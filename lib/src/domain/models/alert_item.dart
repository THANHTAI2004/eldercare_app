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
    this.alertType,
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
  final String? alertType;

  AlertItem copyWith({
    String? id,
    String? title,
    String? message,
    String? severity,
    DateTime? createdAt,
    bool? acknowledged,
    DateTime? acknowledgedAt,
    String? userId,
    String? deviceId,
    String? alertType,
  }) {
    return AlertItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      acknowledged: acknowledged ?? this.acknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      alertType: alertType ?? this.alertType,
    );
  }

  bool get isHighSeverity {
    final normalized = severity.trim().toLowerCase();
    return normalized == 'high' || normalized == 'critical';
  }

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    final id =
        _readString(json['_id']) ??
        _readString(json['alert_id']) ??
        _readString(json['alertId']) ??
        _readString(json['id']) ??
        '';
    final alertType =
        _readString(json['alert_type']) ?? _readString(json['alertType']);
    final title =
        _readString(json['title']) ??
        _readString(json['name']) ??
        _titleFromAlertType(alertType) ??
        _readString(json['type']) ??
        'Canh bao';
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
      alertType: alertType,
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
  if (value is num) {
    final ms = value > 1000000000000
        ? value.toInt()
        : (value * 1000).round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  return DateTime.tryParse(value.toString())?.toUtc();
}

String? _titleFromAlertType(String? alertType) {
  switch (alertType?.trim().toLowerCase()) {
    case 'fall_detected':
      return 'Canh bao te nga';
    case 'spo2_low':
      return 'Canh bao SpO2';
    case 'spo2_critical':
      return 'Canh bao SpO2 nguy kich';
    case 'hr_high':
      return 'Canh bao nhip tim cao';
    case 'hr_low':
      return 'Canh bao nhip tim thap';
    case 'hr_critical':
      return 'Canh bao nhip tim nguy kich';
    case 'hr_low_critical':
      return 'Canh bao nhip tim thap nguy kich';
    case 'temp_high':
      return 'Canh bao nhiet do cao';
    case 'temp_critical':
      return 'Canh bao nhiet do nguy kich';
    case 'temp_low':
      return 'Canh bao nhiet do thap';
    default:
      return null;
  }
}
