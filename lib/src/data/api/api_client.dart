import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getJson(
      String path, {
        Map<String, String>? query,
        Duration timeout = const Duration(seconds: 10),
      }) async {
    final res = await http.get(_uri(path, query)).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
