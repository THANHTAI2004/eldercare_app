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

  testWidgets('claim device success reloads my devices and returns selected device id', (
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

    await tester.tap(find.text('Mở màn liên kết'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dev-esp-001');
    await tester.enterText(find.byType(TextFormField).at(1), 'PAIR-001');
    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(claimApi.lastClaimedDeviceId, 'dev-esp-001');
    expect(claimApi.lastPairingCode, 'PAIR-001');
    expect(deviceProviderApi.getMyDevicesCalls, 1);
    expect(deviceProvider.current?.resolvedDeviceId, 'dev-esp-001');
    expect(find.text('result:dev-esp-001'), findsOneWidget);
  });

  testWidgets('claim device uses shared ApiClient bearer token and sends pairing code', (
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
        expect(options.data, <String, dynamic>{
          'pairing_code': 'PAIR-009',
        });
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

    await tester.tap(find.text('Mở màn liên kết'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dev-esp-009');
    await tester.enterText(find.byType(TextFormField).at(1), 'PAIR-009');
    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(find.text('result:dev-esp-009'), findsOneWidget);
  });

  testWidgets('claim device shows pairing-code specific error for 422 response', (
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

    final claimApi = _TrackingClaimApiService(
      claimError: ApiRequestException(
        method: 'POST',
        path: '/api/v1/devices/dev-esp-404/claim',
        message: 'invalid pairing code',
        statusCode: 422,
      ),
    );

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

    await tester.tap(find.text('Mở màn liên kết'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'dev-esp-404');
    await tester.enterText(find.byType(TextFormField).at(1), 'WRONG-CODE');
    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(
      find.text('Mã ghép nối không đúng hoặc dữ liệu gửi lên chưa hợp lệ.'),
      findsOneWidget,
    );
  });
}

class _ClaimFlowHost extends StatefulWidget {
  const _ClaimFlowHost({this.api});

  final DeviceApiService? api;

  @override
  State<_ClaimFlowHost> createState() => _ClaimFlowHostState();
}

class _ClaimFlowHostState extends State<_ClaimFlowHost> {
  String? _result;

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
                final result = await Navigator.of(context).push<String?>(
                  MaterialPageRoute<String?>(
                    builder: (_) => ClaimDevicePage(api: widget.api),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _result = result;
                });
              },
              child: const Text('Mở màn liên kết'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingClaimApiService extends DeviceApiService {
  _TrackingClaimApiService({this.claimError})
    : super(client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000));

  final Object? claimError;
  String? lastClaimedDeviceId;
  String? lastPairingCode;

  @override
  Future<void> claimDevice({
    required String deviceId,
    required String pairingCode,
  }) async {
    lastClaimedDeviceId = deviceId;
    lastPairingCode = pairingCode;
    if (claimError != null) {
      throw claimError!;
    }
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
