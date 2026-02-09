import 'package:eldercare_app/src/core/utils.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';

class VitalPoint {
  VitalPoint({
    required this.time,
    this.userId,
    this.gatewayId,
    this.hr,
    this.spo2,
    this.temp,
    this.rr,
    this.leadOff,
  });

  final DateTime time;
  final String? userId;
  final String? gatewayId;

  final int? hr;
  final int? spo2;
  final double? temp;
  final int? rr;
  final int? leadOff;

  double? valueOf(Metric metric) {
    switch (metric) {
      case Metric.hr:
        return hr?.toDouble();
      case Metric.spo2:
        return spo2?.toDouble();
      case Metric.temp:
        return temp;
      case Metric.rr:
        return rr?.toDouble();
      case Metric.leadOff:
        return leadOff?.toDouble();
    }
  }

  static VitalPoint fromJson(Map<String, dynamic> json) {
    // ưu tiên ts, _time
    final t = parseTime(json['ts']) ?? parseTime(json['_time']) ?? DateTime.now().toUtc();

    return VitalPoint(
      time: t,
      userId: (json['userId'] ?? json['user_id'])?.toString(),
      gatewayId: (json['gatewayId'] ?? json['gateway_id'])?.toString(),
      hr: toInt(json['hr']),
      spo2: toInt(json['spo2']),
      temp: toDouble(json['temp']),
      rr: toInt(json['rr']),
      leadOff: toInt(json['leadOff']),
    );
  }
}
