import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/device.dart';

void main() {
  group('Device.fromQr', () {
    test('parses manual JSON payload with deviceId', () {
      final device = Device.fromQr(
        '{"userId":"patient-001","deviceId":"dev-esp-001","name":"Phong ngu"}',
      );

      expect(device.id, 'patient-001');
      expect(device.deviceId, 'dev-esp-001');
      expect(device.hasExplicitDeviceId, isTrue);
      expect(device.name, 'Phong ngu');
    });

    test('falls back to plain userId when QR is not JSON', () {
      final device = Device.fromQr('patient-002');

      expect(device.id, 'patient-002');
      expect(device.deviceId, isNull);
      expect(device.hasExplicitDeviceId, isFalse);
    });
  });
}
