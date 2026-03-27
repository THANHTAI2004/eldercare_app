import 'package:eldercare_app/src/core/utils.dart';

class EcgReading {
  EcgReading({
    required this.recordedAt,
    required this.waveform,
    this.deviceId,
    this.samplingRate,
    this.quality,
    this.leadOff,
    this.ecgHr,
  });

  final DateTime recordedAt;
  final List<double> waveform;
  final String? deviceId;
  final int? samplingRate;
  final String? quality;
  final bool? leadOff;
  final int? ecgHr;

  bool get hasWaveform => waveform.isNotEmpty;

  static EcgReading? fromJson(Map<String, dynamic> json) {
    final ecg = _readMap(json['ecg']);
    if (ecg.isEmpty) return null;

    return EcgReading(
      recordedAt:
          parseTime(json['recorded_at']) ??
          parseTime(json['timestamp']) ??
          parseTime(json['created_at']) ??
          DateTime.now().toUtc(),
      waveform: _readWaveform(ecg['waveform']),
      deviceId: _readString(json['device_id'] ?? json['deviceId']),
      samplingRate: toInt(ecg['sampling_rate'] ?? ecg['samplingRate']),
      quality: _readString(ecg['quality']),
      leadOff: _readBool(ecg['lead_off'] ?? ecg['leadOff']),
      ecgHr: toInt(ecg['ecg_hr'] ?? ecg['ecgHr']),
    );
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<double> _readWaveform(dynamic value) {
    if (value is! List) return const <double>[];
    return value
        .map(toDouble)
        .whereType<double>()
        .where((sample) => sample.isFinite)
        .toList(growable: false);
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }
}
