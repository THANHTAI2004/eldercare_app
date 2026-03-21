import 'package:dio/dio.dart';

import 'package:eldercare_app/src/config/env.dart';

class ApiRequestException implements Exception {
  ApiRequestException({
    required this.method,
    required this.path,
    required this.message,
    this.statusCode,
    this.retryAfterSeconds,
    this.responseBody,
  });

  final String method;
  final String path;
  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;
  final Map<String, dynamic>? responseBody;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() {
    final status = statusCode?.toString() ?? 'network';
    return '$method $path failed: $status $message';
  }
}

class ApiClient {
  static const skipAuthRefreshKey = 'skipAuthRefresh';
  static const omitAccessTokenKey = 'omitAccessToken';
  static const retriedAfterRefreshKey = 'retriedAfterRefresh';

  ApiClient._(
    this._dio, {
    required String apiKey,
    required bool sendDefaultApiKey,
  }) : _apiKey = apiKey.trim(),
       _sendDefaultApiKey = sendDefaultApiKey {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Content-Type'] = 'application/json';

          final omitAccessToken = options.extra[omitAccessTokenKey] == true;
          if (!omitAccessToken &&
              _accessToken != null &&
              _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          } else {
            options.headers.remove('Authorization');
          }

          if (_sendDefaultApiKey && _apiKey.isNotEmpty) {
            options.headers['X-API-Key'] = _apiKey;
          } else {
            options.headers.remove('X-API-Key');
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final options = error.requestOptions;
          final shouldTryRefresh =
              response?.statusCode == 401 &&
              options.extra[skipAuthRefreshKey] != true &&
              options.extra[retriedAfterRefreshKey] != true &&
              _onRefreshAccessToken != null;

          if (!shouldTryRefresh) {
            handler.next(error);
            return;
          }

          final nextAccessToken = await _refreshAccessTokenOnce();
          if (nextAccessToken == null || nextAccessToken.isEmpty) {
            if (_onUnauthorized != null) {
              await _onUnauthorized!.call();
            }
            handler.next(error);
            return;
          }

          try {
            final retryOptions = options.copyWith(
              headers: <String, dynamic>{
                ...options.headers,
                'Authorization': 'Bearer $nextAccessToken',
              },
              extra: <String, dynamic>{
                ...options.extra,
                retriedAfterRefreshKey: true,
              },
            );
            final retryResponse = await _dio.fetch<dynamic>(retryOptions);
            handler.resolve(retryResponse);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  factory ApiClient({
    required String baseUrl,
    String apiKey = '',
    required int timeoutMs,
    bool sendDefaultApiKey = false,
  }) {
    return ApiClient._(
      Dio(
        BaseOptions(
          baseUrl: _normalizeBaseUrl(baseUrl),
          connectTimeout: Duration(milliseconds: timeoutMs),
          receiveTimeout: Duration(milliseconds: timeoutMs),
          sendTimeout: Duration(milliseconds: timeoutMs),
        ),
      ),
      apiKey: apiKey,
      sendDefaultApiKey: sendDefaultApiKey,
    );
  }

  factory ApiClient.fromEnv({bool sendDefaultApiKey = false}) {
    return ApiClient(
      baseUrl: Env.apiBaseUrl,
      apiKey: Env.optionalApiKeyForDevOnly,
      timeoutMs: Env.requestTimeoutMs,
      sendDefaultApiKey: sendDefaultApiKey,
    );
  }

  final Dio _dio;
  final String _apiKey;
  final bool _sendDefaultApiKey;
  String? _accessToken;
  Future<String?> Function()? _onRefreshAccessToken;
  Future<void> Function()? _onUnauthorized;
  Future<String?>? _refreshFuture;

  Dio get dio => _dio;

  String? get accessToken => _accessToken;

  void setAccessToken(String? token) {
    final trimmed = token?.trim();
    _accessToken = trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void clearAccessToken() {
    _accessToken = null;
  }

  void configureAuthCallbacks({
    Future<String?> Function()? onRefreshAccessToken,
    Future<void> Function()? onUnauthorized,
  }) {
    _onRefreshAccessToken = onRefreshAccessToken;
    _onUnauthorized = onUnauthorized;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: headers, extra: extra),
      );
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e, method: 'GET', path: path);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(headers: headers, extra: extra),
      );
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e, method: 'POST', path: path);
    }
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final res = await _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(headers: headers, extra: extra),
      );
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e, method: 'PUT', path: path);
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final res = await _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(headers: headers, extra: extra),
      );
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e, method: 'PATCH', path: path);
    }
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final res = await _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(headers: headers, extra: extra),
      );
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e, method: 'DELETE', path: path);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        raw,
        'baseUrl',
        'API_BASE_URL must not be empty',
      );
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  ApiRequestException _toApiException(
    DioException e, {
    required String method,
    required String path,
  }) {
    final status = e.response?.statusCode;
    final body = _asNullableMap(e.response?.data);
    final message = _readErrorMessage(status, body, fallback: e.message);
    final retryAfter = int.tryParse(
      e.response?.headers.value('Retry-After') ?? '',
    );

    return ApiRequestException(
      method: method,
      path: path,
      message: message,
      statusCode: status,
      retryAfterSeconds: retryAfter,
      responseBody: body,
    );
  }

  Map<String, dynamic>? _asNullableMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _readErrorMessage(
    int? status,
    Map<String, dynamic>? body, {
    String? fallback,
  }) {
    final detail = body?['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }

    final message = body?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    if (status == 401) return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn';
    if (status == 403) return 'Bạn không có quyền thực hiện thao tác này';
    if (status == 404) return 'Không tìm thấy dữ liệu';
    if (status == 422) return 'Dữ liệu gửi lên không hợp lệ';
    if (status == 429) return 'Có quá nhiều yêu cầu, vui lòng thử lại sau';

    if (status == null) {
      return 'Không thể kết nối đến máy chủ';
    }

    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return 'Yêu cầu thất bại';
  }

  Future<String?> _refreshAccessTokenOnce() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final callback = _onRefreshAccessToken;
    if (callback == null) {
      return Future<String?>.value(null);
    }

    final future = callback();
    _refreshFuture = future;
    future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
    return future;
  }
}
