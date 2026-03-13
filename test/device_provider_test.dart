import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'handleSessionState loads my devices and auto-selects single device',
    () async {
      final provider = DeviceProvider(
        api: _FakeDeviceApiService(
          devices: <Device>[
            Device.fromServerJson({
              'device_id': 'dev-esp-001',
              'name': 'Phong ngu',
              'linked_users': [
                {'user_id': 'patient-001', 'name': 'Patient 001'},
              ],
            }),
          ],
        ),
      );

      await provider.handleSessionState(
        isAuthenticated: true,
        authenticatedUserId: 'patient-001',
      );

      expect(provider.devices, hasLength(1));
      expect(provider.current?.resolvedDeviceId, 'dev-esp-001');
      expect(provider.current?.primaryUserId, 'patient-001');
    },
  );

  test('syncFromServer keeps current device when it still exists', () async {
    final provider = DeviceProvider(
      api: _FakeDeviceApiService(
        devices: <Device>[
          Device.fromServerJson({
            'device_id': 'dev-esp-001',
            'name': 'Device A',
            'linked_users': [
              {'user_id': 'patient-001', 'name': 'Patient 001'},
            ],
          }),
          Device.fromServerJson({
            'device_id': 'dev-esp-002',
            'name': 'Device B',
            'linked_users': [
              {'user_id': 'patient-001', 'name': 'Patient 001'},
            ],
          }),
        ],
      ),
    );

    await provider.syncFromServer(authenticatedUserId: 'patient-001');
    await provider.setCurrent('dev-esp-002');
    await provider.syncFromServer(authenticatedUserId: 'patient-001');

    expect(provider.current?.resolvedDeviceId, 'dev-esp-002');
  });
}

class _FakeDeviceApiService extends DeviceApiService {
  _FakeDeviceApiService({required this.devices})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<Device> devices;

  @override
  Future<List<Device>> getMyDevices() async => devices;
}
