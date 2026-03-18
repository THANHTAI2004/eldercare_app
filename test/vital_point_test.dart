import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/vital_point.dart';

void main() {
  group('VitalPoint.fromJson', () {
    test('parses flat backend reading fields', () {
      final point = VitalPoint.fromJson(<String, dynamic>{
        'timestamp': '2026-03-11T10:30:00Z',
        'user_id': 'user-001',
        'device_id': 'dev-esp-001',
        'heart_rate': 72,
        'spo2': 98,
        'temperature': 36.7,
        'respiratory_rate': 18,
      });

      expect(point.userId, 'user-001');
      expect(point.deviceId, 'dev-esp-001');
      expect(point.hr, 72);
      expect(point.spo2, 98);
      expect(point.temp, 36.7);
      expect(point.rr, 18);
      expect(point.time.toUtc(), DateTime.parse('2026-03-11T10:30:00Z'));
    });

    test('parses nested vitals payload', () {
      final point = VitalPoint.fromJson(<String, dynamic>{
        'recorded_at': '2026-03-11T10:35:00Z',
        'user_id': 'user-002',
        'vitals': <String, dynamic>{
          'device_id': 'dev-esp-002',
          'heart_rate': 80,
          'spo2': 96,
          'temperature': 37.1,
          'respiratory_rate': 20,
        },
      });

      expect(point.userId, 'user-002');
      expect(point.deviceId, 'dev-esp-002');
      expect(point.hr, 80);
      expect(point.spo2, 96);
      expect(point.temp, 37.1);
      expect(point.rr, 20);
      expect(point.time.toUtc(), DateTime.parse('2026-03-11T10:35:00Z'));
    });
  });
}
