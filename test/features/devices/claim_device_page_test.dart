import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/auth_tokens.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/claim_device_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

import '../../support/auth_widget_test_support.dart';
import '../../support/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setUpSharedPreferences();
  });

  testWidgets('claim device success reloads my devices and returns true', (
    tester,
  ) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'owner-001',
        'name': 'Owner A',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987654321', password: 'MatKhau123');

    final deviceProviderApi = _TrackingMyDevicesApiService(
      devices: <Device>[
        Device.fromServerJson(const <String, dynamic>{
          'device_id': 'dev-esp-001',
          'name': 'Phong ngu',
          'user_id': 'owner-001',
          'link_role': 'owner',
          'linked_users': <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'owner-001',
              'name': 'Owner A',
              'link_role': 'owner',
            },
          ],
        }),
      ],
    );
    final deviceProvider = DeviceProvider(api: deviceProviderApi);
    await deviceProvider.load();

    final claimApi = _TrackingClaimApiService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ],
        child: MaterialApp(home: _ClaimFlowHost(api: claimApi)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mo man lien ket'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ma thiet bi'),
      'dev-esp-001',
    );
    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(claimApi.lastClaimedDeviceId, 'dev-esp-001');
    expect(deviceProviderApi.getMyDevicesCalls, 1);
    expect(deviceProvider.devices, hasLength(1));
    expect(deviceProvider.devices.single.resolvedDeviceId, 'dev-esp-001');
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('claim device uses shared ApiClient bearer token by default', (
    tester,
  ) async {
    final session = buildSessionProvider(
      loginTokens: const AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      ),
      meResponse: const <String, dynamic>{
        'user_id': 'owner-001',
        'name': 'Owner A',
        'role': 'member',
      },
    );
    await session.login(phoneNumber: '0987654321', password: 'MatKhau123');

    final deviceProvider = DeviceProvider(
      api: _TrackingMyDevicesApiService(devices: const <Device>[]),
    );
    await deviceProvider.load();

    final sharedClient = ApiClient(
      baseUrl: 'https://example.com',
      timeoutMs: 1000,
    )..setAccessToken('shared-access');
    sharedClient.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-esp-009/claim');
        expect(options.headers['Authorization'], 'Bearer shared-access');
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: sharedClient),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ],
        child: const MaterialApp(home: _ClaimFlowHost()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mo man lien ket'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ma thiet bi'),
      'dev-esp-009',
    );
    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(find.text('result:true'), findsOneWidget);
  });
}

class _ClaimFlowHost extends StatefulWidget {
  const _ClaimFlowHost({this.api});

  final DeviceApiService? api;

  @override
  State<_ClaimFlowHost> createState() => _ClaimFlowHostState();
}

class _ClaimFlowHostState extends State<_ClaimFlowHost> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('result:${_result ?? 'pending'}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ClaimDevicePage(api: widget.api),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _result = result;
                });
              },
              child: const Text('Mo man lien ket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingClaimApiService extends DeviceApiService {
  _TrackingClaimApiService()
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  String? lastClaimedDeviceId;

  @override
  Future<void> claimDevice({required String deviceId}) async {
    lastClaimedDeviceId = deviceId;
  }
}

class _TrackingMyDevicesApiService extends DeviceApiService {
  _TrackingMyDevicesApiService({required this.devices})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final List<Device> devices;
  int getMyDevicesCalls = 0;

  @override
  Future<List<Device>> getMyDevices() async {
    getMyDevicesCalls += 1;
    return devices;
  }
}
