import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/device.dart';

void main() {
  group('Device.fromQr', () {
    test('parses manual JSON payload with deviceId', () {
      final device = Device.fromQr(
        '{"userId":"user-001","deviceId":"dev-esp-001","name":"Phong ngu"}',
      );

      expect(device.id, 'dev-esp-001');
      expect(device.resolvedDeviceId, 'dev-esp-001');
      expect(device.primaryUserId, 'user-001');
      expect(device.hasExplicitDeviceId, isTrue);
      expect(device.name, 'Phong ngu');
    });

    test('falls back to plain userId when QR is not JSON', () {
      final device = Device.fromQr('user-002');

      expect(device.id, 'user-002');
      expect(device.primaryUserId, 'user-002');
      expect(device.hasExplicitDeviceId, isFalse);
    });
  });

  group('Device.fromServerJson', () {
    test('parses linked users from me/devices response item', () {
      final device = Device.fromServerJson({
        'device_id': 'dev-esp-009',
        'name': 'Phong khach',
        'link_role': 'owner',
        'linked_users': [
          {
            'user_id': 'owner-009',
            'full_name': 'Owner 009',
            'link_role': 'owner',
          },
          {
            'user_id': 'viewer-001',
            'name': 'Viewer 001',
            'link_role': 'viewer',
            'phone_number': '0909000111',
          },
        ],
      });

      expect(device.id, 'dev-esp-009');
      expect(device.name, 'Phong khach');
      expect(device.linkRole, 'owner');
      expect(device.isOwnerLink, isTrue);
      expect(device.primaryUserId, 'owner-009');
      expect(device.linkedUsers, hasLength(2));
      expect(device.linkedUsers.first.displayName, 'Owner 009');
      expect(device.linkedUsers.last.linkRole, 'viewer');
      expect(device.linkedUsers.last.phoneNumber, '0909000111');
    });
  });
}
