import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class VitalsApi {
  VitalsApi(this._client);

  final ApiClient _client;

  Future<VitalPoint> latest({required String userId}) async {
    final json = await _client.getJson('/latest', query: {'userId': userId});
    return VitalPoint.fromJson(json);
  }

  /// API của bạn đang dùng kiểu: /history?userId=u01&from=-1h&to=now()&window=10s
  Future<List<VitalPoint>> history({
    required String userId,
    String from = '-7d',
    String to = 'now()',
    String window = '10m',
  }) async {
    final json = await _client.getJson('/history', query: {
      'userId': userId,
      'from': from,
      'to': to,
      'window': window,
    });

    final points = (json['points']);
    if (points is! List) return <VitalPoint>[];
    return points
        .whereType<Map>()
        .map((e) => VitalPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
