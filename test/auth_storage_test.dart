import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/local/auth_storage.dart';

import 'support/test_helpers.dart';

void main() {
  setUp(() {
    setUpSharedPreferences();
  });

  test('saves and loads access token and refresh token', () async {
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);

    await storage.saveAccessToken('access-123');
    await storage.saveRefreshToken('refresh-456');

    expect(await storage.loadAccessToken(), 'access-123');
    expect(await storage.loadRefreshToken(), 'refresh-456');
  });

  test('saves and loads current user from shared preferences', () async {
    final storage = AuthStorage(secureStore: MemorySecureStore());

    await storage.saveCurrentUser(<String, dynamic>{
      'user_id': 'user-001',
      'role': 'member',
    });

    final currentUser = await storage.loadCurrentUser();

    expect(currentUser?['user_id'], 'user-001');
    expect(currentUser?['role'], 'member');
  });

  test('clear removes all persisted auth data', () async {
    final secureStore = MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);

    await storage.saveAccessToken('access-123');
    await storage.saveRefreshToken('refresh-456');
    await storage.saveCurrentUser(<String, dynamic>{'user_id': 'user-001'});

    await storage.clear();

    expect(await storage.loadAccessToken(), isNull);
    expect(await storage.loadRefreshToken(), isNull);
    expect(await storage.loadCurrentUser(), isNull);
  });
}
