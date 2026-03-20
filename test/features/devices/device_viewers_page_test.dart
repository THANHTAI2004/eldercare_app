import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/device_viewers_page.dart';

import '../../support/test_helpers.dart';

void main() {
  testWidgets('owner loads linked users and only shows viewers', (
    tester,
  ) async {
    final api = _FakeDeviceApiService(
      initialUsers: <DeviceLinkedUser>[
        const DeviceLinkedUser(
          id: 'owner-001',
          name: 'Owner',
          linkRole: 'owner',
        ),
        const DeviceLinkedUser(
          id: 'viewer-001',
          name: 'Viewer A',
          linkRole: 'viewer',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceViewersPage(
          device: Device(id: 'dev-001', name: 'Phong ngu', linkRole: 'owner'),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.getLinkedUsersCalls, 1);
    expect(find.text('Viewer A'), findsOneWidget);
    expect(find.text('Owner'), findsNothing);
  });

  testWidgets('owner uses shared ApiClient bearer token by default', (
    tester,
  ) async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000)
      ..setAccessToken('shared-access');
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/devices/dev-001/linked-users');
        expect(options.headers['Authorization'], 'Bearer shared-access');
        return jsonResponse(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'viewer-001',
              'name': 'Viewer A',
              'link_role': 'viewer',
            },
          ],
        }, 200);
      },
    );

    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: client,
        child: MaterialApp(
          home: DeviceViewersPage(
            device: Device(id: 'dev-001', name: 'Phong ngu', linkRole: 'owner'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Viewer A'), findsOneWidget);
  });

  testWidgets('viewer cannot load or manage viewers', (tester) async {
    final api = _FakeDeviceApiService(
      initialUsers: const <DeviceLinkedUser>[
        DeviceLinkedUser(
          id: 'viewer-001',
          name: 'Viewer A',
          linkRole: 'viewer',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceViewersPage(
          device: Device(id: 'dev-001', name: 'Phong ngu', linkRole: 'viewer'),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.getLinkedUsersCalls, 0);
    expect(
      find.text('Chỉ chủ thiết bị mới có thể quản lý người xem của thiết bị này.'),
      findsOneWidget,
    );
  });

  testWidgets('owner adds and removes viewer by account id then reloads', (
    tester,
  ) async {
    final api = _FakeDeviceApiService(initialUsers: const <DeviceLinkedUser>[]);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceViewersPage(
          device: Device(id: 'dev-001', name: 'Phong ngu', linkRole: 'owner'),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mã tài khoản'),
      'viewer-001',
    );
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();

    expect(api.lastAddUserId, 'viewer-001');
    expect(api.getLinkedUsersCalls, 2);
    expect(find.text('viewer-001'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();

    expect(api.lastRemoveUserId, 'viewer-001');
    expect(api.getLinkedUsersCalls, 3);
    expect(find.text('viewer-001'), findsNothing);
  });

  testWidgets('422 from add viewer is mapped to a friendly message', (
    tester,
  ) async {
    final api = _FakeDeviceApiService(
      initialUsers: const <DeviceLinkedUser>[],
      addError: ApiRequestException(
        method: 'POST',
        path: '/api/v1/devices/dev-001/viewers',
        message: 'payload invalid',
        statusCode: 422,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceViewersPage(
          device: Device(id: 'dev-001', name: 'Phong ngu', linkRole: 'owner'),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mã tài khoản'),
      'viewer-001',
    );
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();

    expect(
      find.text('Dữ liệu gửi lên không đúng định dạng máy chủ yêu cầu.'),
      findsOneWidget,
    );
  });
}

class _FakeDeviceApiService extends DeviceApiService {
  _FakeDeviceApiService({
    required List<DeviceLinkedUser> initialUsers,
    this.addError,
  }) : _users = List<DeviceLinkedUser>.from(initialUsers),
       super(
         client: ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000),
       );

  final List<DeviceLinkedUser> _users;
  final ApiRequestException? addError;

  int getLinkedUsersCalls = 0;
  String? lastAddUserId;
  String? lastRemoveUserId;

  @override
  Future<List<DeviceLinkedUser>> getLinkedUsers({
    required String deviceId,
  }) async {
    getLinkedUsersCalls += 1;
    return List<DeviceLinkedUser>.unmodifiable(_users);
  }

  @override
  Future<void> addViewer({
    required String deviceId,
    required String userId,
  }) async {
    if (addError != null) throw addError!;
    lastAddUserId = userId;
    _users.add(DeviceLinkedUser(id: userId, name: userId, linkRole: 'viewer'));
  }

  @override
  Future<void> removeViewer({
    required String deviceId,
    required String userId,
  }) async {
    lastRemoveUserId = userId;
    _users.removeWhere((user) => user.id == userId);
  }
}
