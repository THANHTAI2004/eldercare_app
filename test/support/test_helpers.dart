import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/data/local/auth_storage.dart';

typedef AdapterHandler =
    Future<ResponseBody> Function(RequestOptions options, int callCount);

class StubHttpClientAdapter implements HttpClientAdapter {
  StubHttpClientAdapter({required this.handler});

  final AdapterHandler handler;
  final List<RequestOptions> requests = <RequestOptions>[];
  int _callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _callCount += 1;
    requests.add(options);
    return handler(options, _callCount);
  }

  @override
  void close({bool force = false}) {}
}

class MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

ResponseBody jsonResponse(
  Object body,
  int statusCode, {
  Map<String, List<String>> headers = const <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: headers,
  );
}

Never throwConnectionError(RequestOptions options, {String message = 'offline'}) {
  throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    error: message,
    message: message,
  );
}

void setUpSharedPreferences() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
}
