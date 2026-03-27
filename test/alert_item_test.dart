import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/alert_item.dart';

void main() {
  test('AlertItem.fromJson parses _id, alert_type, severity, ack and ids', () {
    final item = AlertItem.fromJson({
      '_id': 'mongo-alert-001',
      'alert_type': 'fall_detected',
      'message': 'Fall detected near bed',
      'severity': 'critical',
      'timestamp': 1773396000,
      'acknowledged': false,
      'user_id': 'user-001',
      'device_id': 'dev-esp-001',
    });

    expect(item.id, 'mongo-alert-001');
    expect(item.alertType, 'fall_detected');
    expect(item.title, 'Canh bao te nga');
    expect(item.createdAt, DateTime.parse('2026-03-13T10:00:00Z'));
    expect(item.isHighSeverity, isTrue);
    expect(item.acknowledged, isFalse);
    expect(item.userId, 'user-001');
    expect(item.deviceId, 'dev-esp-001');
  });
}
