import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/alert_item.dart';

void main() {
  test('AlertItem.fromJson parses severity, ack and ids', () {
    final item = AlertItem.fromJson({
      'alert_id': 'alert-001',
      'title': 'Nhịp tim bất thường',
      'message': 'HR > 130',
      'severity': 'critical',
      'created_at': '2026-03-13T10:00:00Z',
      'acknowledged': false,
      'user_id': 'user-001',
      'device_id': 'dev-esp-001',
    });

    expect(item.id, 'alert-001');
    expect(item.isHighSeverity, isTrue);
    expect(item.acknowledged, isFalse);
    expect(item.userId, 'user-001');
    expect(item.deviceId, 'dev-esp-001');
  });
}
