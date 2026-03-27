class DeviceThresholds {
  const DeviceThresholds({
    this.spo2Low,
    this.spo2Critical,
    this.tempLow,
    this.tempHigh,
    this.tempCritical,
    this.hrLow,
    this.hrLowCritical,
    this.hrHigh,
    this.hrCritical,
    this.rrLow,
    this.rrHigh,
  });

  final double? spo2Low;
  final double? spo2Critical;
  final double? tempLow;
  final double? tempHigh;
  final double? tempCritical;
  final double? hrLow;
  final double? hrLowCritical;
  final double? hrHigh;
  final double? hrCritical;
  final double? rrLow;
  final double? rrHigh;

  factory DeviceThresholds.fromJson(Map<String, dynamic> json) {
    return DeviceThresholds(
      spo2Low: _readDouble(json['spo2_low']),
      spo2Critical: _readDouble(json['spo2_critical']),
      tempLow: _readDouble(json['temp_low']),
      tempHigh: _readDouble(json['temp_high']),
      tempCritical: _readDouble(json['temp_critical']),
      hrLow: _readDouble(json['hr_low']),
      hrLowCritical: _readDouble(
        json['hr_low_critical'] ?? json['hr_critical_low'],
      ),
      hrHigh: _readDouble(json['hr_high']),
      hrCritical: _readDouble(json['hr_critical']),
      rrLow: _readDouble(json['rr_low']),
      rrHigh: _readDouble(json['rr_high']),
    );
  }

  DeviceThresholds copyWith({
    double? spo2Low,
    double? spo2Critical,
    double? tempLow,
    double? tempHigh,
    double? tempCritical,
    double? hrLow,
    double? hrLowCritical,
    double? hrHigh,
    double? hrCritical,
    double? rrLow,
    double? rrHigh,
  }) {
    return DeviceThresholds(
      spo2Low: spo2Low ?? this.spo2Low,
      spo2Critical: spo2Critical ?? this.spo2Critical,
      tempLow: tempLow ?? this.tempLow,
      tempHigh: tempHigh ?? this.tempHigh,
      tempCritical: tempCritical ?? this.tempCritical,
      hrLow: hrLow ?? this.hrLow,
      hrLowCritical: hrLowCritical ?? this.hrLowCritical,
      hrHigh: hrHigh ?? this.hrHigh,
      hrCritical: hrCritical ?? this.hrCritical,
      rrLow: rrLow ?? this.rrLow,
      rrHigh: rrHigh ?? this.rrHigh,
    );
  }

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      if (spo2Low != null) 'spo2_low': _toPayloadNumber(spo2Low!),
      if (spo2Critical != null)
        'spo2_critical': _toPayloadNumber(spo2Critical!),
      if (tempLow != null) 'temp_low': _toPayloadNumber(tempLow!),
      if (tempHigh != null) 'temp_high': _toPayloadNumber(tempHigh!),
      if (tempCritical != null)
        'temp_critical': _toPayloadNumber(tempCritical!),
      if (hrLow != null) 'hr_low': _toPayloadNumber(hrLow!),
      if (hrLowCritical != null)
        'hr_low_critical': _toPayloadNumber(hrLowCritical!),
      if (hrHigh != null) 'hr_high': _toPayloadNumber(hrHigh!),
      if (hrCritical != null) 'hr_critical': _toPayloadNumber(hrCritical!),
      if (rrLow != null) 'rr_low': _toPayloadNumber(rrLow!),
      if (rrHigh != null) 'rr_high': _toPayloadNumber(rrHigh!),
    };
  }

  String toFingerprint() => toPayload().toString();

  static num _toPayloadNumber(double value) {
    return value == value.roundToDouble() ? value.toInt() : value;
  }
}

double? _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return double.tryParse(text);
}
