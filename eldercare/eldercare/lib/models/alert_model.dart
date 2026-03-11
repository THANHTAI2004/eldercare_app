/// Alert severity levels
enum AlertSeverity { info, warning, critical }

/// Alert model
class AlertModel {
  final String alertId;
  final String userId;
  final AlertSeverity severity;
  final String type;
  final String message;
  final double? value;
  final double? threshold;
  final DateTime timestamp;
  final bool acknowledged;
  final String? acknowledgedBy;
  final String? notes;

  AlertModel({
    required this.alertId,
    required this.userId,
    required this.severity,
    required this.type,
    required this.message,
    this.value,
    this.threshold,
    required this.timestamp,
    required this.acknowledged,
    this.acknowledgedBy,
    this.notes,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      alertId: json['alert_id'] as String,
      userId: json['user_id'] as String,
      severity: _parseSeverity(json['severity'] as String),
      type: json['type'] as String,
      message: json['message'] as String,
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      threshold: json['threshold'] != null
          ? (json['threshold'] as num).toDouble()
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((json['timestamp'] as num).toDouble() * 1000).toInt(),
      ),
      acknowledged: json['acknowledged'] as bool? ?? false,
      acknowledgedBy: json['acknowledged_by'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_id': alertId,
      'user_id': userId,
      'severity': severity.name,
      'type': type,
      'message': message,
      if (value != null) 'value': value,
      if (threshold != null) 'threshold': threshold,
      'timestamp': timestamp.millisecondsSinceEpoch / 1000,
      'acknowledged': acknowledged,
      if (acknowledgedBy != null) 'acknowledged_by': acknowledgedBy,
      if (notes != null) 'notes': notes,
    };
  }

  static AlertSeverity _parseSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'info':
        return AlertSeverity.info;
      case 'warning':
        return AlertSeverity.warning;
      case 'critical':
        return AlertSeverity.critical;
      default:
        return AlertSeverity.info;
    }
  }
}
