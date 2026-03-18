import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';

import 'support/test_helpers.dart';

void main() {
  test('getMyDevices reads items from /api/v1/me/devices', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = DeviceApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/me/devices');
        return jsonResponse(<String, dynamic>{
          'count': 1,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'device_id': 'dev-esp-001',
              'name': 'Phong ngu',
              'linked_users': <Map<String, dynamic>>[
                <String, dynamic>{
                  'user_id': 'patient-001',
                  'name': 'Nguyen Van A',
                  'role': 'patient',
                  'link_role': 'owner',
                  'phone_number': '0987654321',
                },
              ],
            },
          ],
        }, 200);
      },
    );

    final devices = await service.getMyDevices();

    expect(devices, hasLength(1));
    expect(devices.single.resolvedDeviceId, 'dev-esp-001');
    expect(devices.single.linkedUsers.single.linkRole, 'owner');
    expect(devices.single.linkedUsers.single.phoneNumber, '0987654321');
  });

  test('getMyDevices returns empty list when items is empty', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = DeviceApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/me/devices');
        return jsonResponse(<String, dynamic>{
          'count': 0,
          'items': const <Map<String, dynamic>>[],
        }, 200);
      },
    );

    final devices = await service.getMyDevices();

    expect(devices, isEmpty);
  });

  test('claimDevice posts to claim endpoint', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = DeviceApiService(client: client);
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-esp-001/claim');
        expect(options.method, 'POST');
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );

    await service.claimDevice(deviceId: 'dev-esp-001');
  });

  test('addViewer and removeViewer call viewer endpoints', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = DeviceApiService(client: client);
    var removeCalled = false;
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        if (options.method == 'POST') {
          expect(options.path, '/api/v1/devices/dev-esp-001/viewers');
          expect(options.data, <String, dynamic>{'user_id': 'viewer-001'});
          return jsonResponse(<String, dynamic>{'ok': true}, 200);
        }

        expect(options.method, 'DELETE');
        expect(options.path, '/api/v1/devices/dev-esp-001/viewers/viewer-001');
        removeCalled = true;
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );

    await service.addViewer(deviceId: 'dev-esp-001', userId: 'viewer-001');
    await service.removeViewer(deviceId: 'dev-esp-001', userId: 'viewer-001');

    expect(removeCalled, isTrue);
  });
}
