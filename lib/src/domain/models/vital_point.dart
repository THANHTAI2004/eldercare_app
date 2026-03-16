import 'package:eldercare_app/src/core/utils.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';

class VitalPoint {
  VitalPoint({
    required this.time,
    this.userId,
    this.deviceId,
    this.gatewayId,
    this.hr,
    this.spo2,
    this.temp,
    this.rr,
    this.leadOff,
  });

  final DateTime time;
  final String? userId;
  final String? deviceId;
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'time': time.toUtc().toIso8601String(),
      if (userId != null && userId!.trim().isNotEmpty) 'user_id': userId,
      if (deviceId != null && deviceId!.trim().isNotEmpty) 'device_id': deviceId,
      if (gatewayId != null && gatewayId!.trim().isNotEmpty)
        'gateway_id': gatewayId,
      if (hr != null) 'hr': hr,
      if (spo2 != null) 'spo2': spo2,
      if (temp != null) 'temp': temp,
      if (rr != null) 'rr': rr,
      if (leadOff != null) 'leadOff': leadOff,
    };
  }

  static VitalPoint fromJson(Map<String, dynamic> json) {
    final vitals = _readMap(json['vitals']);

    final t =
        parseTime(json['ts']) ??
        parseTime(json['timestamp']) ??
        parseTime(json['_time']) ??
        parseTime(json['time']) ??
        parseTime(json['recorded_at']) ??
        parseTime(json['created_at']) ??
        parseTime(vitals['ts']) ??
        parseTime(vitals['timestamp']) ??
        parseTime(vitals['recorded_at']) ??
        DateTime.now().toUtc();

    return VitalPoint(
      time: t,
      userId: _readString(
        json['userId'] ?? json['user_id'] ?? json['uid'] ?? vitals['user_id'],
      ),
      deviceId: _readString(
        json['deviceId'] ??
            json['device_id'] ??
            json['device'] ??
            vitals['device_id'] ??
            vitals['deviceId'],
      ),
      gatewayId: _readString(
        json['gatewayId'] ??
            json['gateway_id'] ??
            vitals['gateway_id'] ??
            vitals['gatewayId'],
      ),
      hr: _readInt(json, vitals, const ['hr', 'heart_rate', 'pulse']),
      spo2: _readInt(json, vitals, const [
        'spo2',
        'sp_o2',
        'oxygen_saturation',
      ]),
      temp: _readDouble(json, vitals, const [
        'temp',
        'temperature',
        'body_temp',
      ]),
      rr: _readInt(json, vitals, const ['rr', 'respiratory_rate', 'resp_rate']),
      leadOff: _readInt(json, vitals, const ['leadOff', 'lead_off', 'leadoff']),
    );
  }

  static int? _readInt(
    Map<String, dynamic> root,
    Map<String, dynamic> vitals,
    List<String> keys,
  ) {
    for (final key in keys) {
      final direct = toInt(root[key]);
      if (direct != null) return direct;
      final nested = toInt(vitals[key]);
      if (nested != null) return nested;
    }
    return null;
  }

  static double? _readDouble(
    Map<String, dynamic> root,
    Map<String, dynamic> vitals,
    List<String> keys,
  ) {
    for (final key in keys) {
      final direct = toDouble(root[key]);
      if (direct != null) return direct;
      final nested = toDouble(vitals[key]);
      if (nested != null) return nested;
    }
    return null;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String? _readString(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }
}
