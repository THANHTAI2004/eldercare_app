import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';

import 'support/test_helpers.dart';

void main() {
  test('adds Authorization header when access token is set', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        expect(options.headers['Authorization'], 'Bearer access-123');
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;
    client.setAccessToken('access-123');

    final json = await client.getJson('/secure');

    expect(json['ok'], true);
  });

  test('retries request after refresh callback returns a new token', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    var refreshCalls = 0;

    client.configureAuthCallbacks(
      onRefreshAccessToken: () async {
        refreshCalls += 1;
        client.setAccessToken('fresh-token');
        return 'fresh-token';
      },
    );

    final adapter = StubHttpClientAdapter(
      handler: (options, callCount) async {
        if (callCount == 1) {
          expect(options.headers['Authorization'], 'Bearer stale-token');
          return jsonResponse(<String, dynamic>{'detail': 'expired'}, 401);
        }

        expect(options.headers['Authorization'], 'Bearer fresh-token');
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      },
    );
    client.dio.httpClientAdapter = adapter;
    client.setAccessToken('stale-token');

    final json = await client.getJson('/secure');

    expect(refreshCalls, 1);
    expect(adapter.requests, hasLength(2));
    expect(json['ok'], true);
  });

  test('calls unauthorized callback when refresh fails', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    var unauthorizedCalls = 0;

    client.configureAuthCallbacks(
      onRefreshAccessToken: () async => null,
      onUnauthorized: () async {
        unauthorizedCalls += 1;
      },
    );

    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        return jsonResponse(<String, dynamic>{'detail': 'expired'}, 401);
      },
    );
    client.dio.httpClientAdapter = adapter;
    client.setAccessToken('stale-token');

    await expectLater(
      client.getJson('/secure'),
      throwsA(isA<ApiRequestException>()),
    );

    expect(unauthorizedCalls, 1);
  });

  test('maps network errors to a friendly message', () async {
    final client = ApiClient(baseUrl: 'https://example.com', timeoutMs: 1000);
    final adapter = StubHttpClientAdapter(
      handler: (options, _) async {
        throwConnectionError(options, message: 'socket closed');
      },
    );
    client.dio.httpClientAdapter = adapter;

    try {
      await client.getJson('/health');
      fail('Expected ApiRequestException');
    } on ApiRequestException catch (e) {
      expect(e.statusCode, isNull);
      expect(e.isNetworkError, isTrue);
      expect(e.message, 'Không thể kết nối đến máy chủ');
    }
  });
}
