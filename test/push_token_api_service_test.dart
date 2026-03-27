import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/push_token_api_service.dart';

import 'support/test_helpers.dart';

void main() {
  test('registerPushToken posts to the configured path', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = PushTokenApiService(
      client: client,
      path: '/api/v1/custom-push-tokens',
    );

    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.path, '/api/v1/custom-push-tokens');
        expect(options.method, 'POST');
        expect(options.data, <String, dynamic>{
          'token': 'abc',
          'platform': 'android',
        });
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );

    await service.registerPushToken(token: 'abc', platform: 'android');
  });

  test('registerPushToken maps 404 to unsupported-endpoint exception', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final service = PushTokenApiService(
      client: client,
      path: '/api/v1/custom-push-tokens',
    );

    client.dio.httpClientAdapter = StubHttpClientAdapter(
      handler: (options, _) async {
        return jsonResponse(<String, dynamic>{'detail': 'Not Found'}, 404);
      },
    );

    await expectLater(
      service.registerPushToken(token: 'abc', platform: 'android'),
      throwsA(isA<PushTokenEndpointUnsupportedException>()),
    );
  });
}
