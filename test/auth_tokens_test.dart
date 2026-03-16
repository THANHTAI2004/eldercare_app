import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/auth_tokens.dart';

void main() {
  test('AuthTokens.fromJson reads snake_case tokens', () {
    final tokens = AuthTokens.fromJson(<String, dynamic>{
      'access_token': 'access-123',
      'refresh_token': 'refresh-456',
    });

    expect(tokens.accessToken, 'access-123');
    expect(tokens.refreshToken, 'refresh-456');
    expect(tokens.hasRefreshToken, isTrue);
  });

  test('AuthTokens.fromJson accepts camelCase fallback keys', () {
    final tokens = AuthTokens.fromJson(<String, dynamic>{
      'accessToken': 'access-abc',
      'refreshToken': 'refresh-def',
    });

    expect(tokens.accessToken, 'access-abc');
    expect(tokens.refreshToken, 'refresh-def');
  });
}
