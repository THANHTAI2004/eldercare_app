/// ECG data structure
class ECGData {
  final List<double> waveform;
  final int samplingRate;
  final double duration;
  final String quality;
  final bool? leadOff;

  ECGData({
    required this.waveform,
    required this.samplingRate,
    required this.duration,
    required this.quality,
    this.leadOff,
  });

  factory ECGData.fromJson(Map<String, dynamic> json) {
    return ECGData(
      waveform: (json['waveform'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      samplingRate: json['sampling_rate'] as int,
      duration: (json['duration'] as num).toDouble(),
      quality: json['quality'] as String,
      leadOff: json['lead_off'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waveform': waveform,
      'sampling_rate': samplingRate,
      'duration': duration,
      'quality': quality,
      if (leadOff != null) 'lead_off': leadOff,
    };
  }
}

/// Vitals data structure
class VitalsData {
  final int? heartRate;
  final int? respiratoryRate;
  final double? spo2;
  final double? temperature;

  VitalsData({
    this.heartRate,
    this.respiratoryRate,
    this.spo2,
    this.temperature,
  });

  factory VitalsData.fromJson(Map<String, dynamic> json) {
    return VitalsData(
      heartRate: json['heart_rate'] as int?,
      respiratoryRate: json['respiratory_rate'] as int?,
      spo2: json['spo2'] != null ? (json['spo2'] as num).toDouble() : null,
      temperature: json['temperature'] != null
          ? (json['temperature'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (heartRate != null) 'heart_rate': heartRate,
      if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
      if (spo2 != null) 'spo2': spo2,
      if (temperature != null) 'temperature': temperature,
    };
  }
}

/// Metadata structure
class MetadataData {
  final int? batteryLevel;
  final int? signalStrength;
  final String? firmwareVersion;

  MetadataData({this.batteryLevel, this.signalStrength, this.firmwareVersion});

  factory MetadataData.fromJson(Map<String, dynamic> json) {
    return MetadataData(
      batteryLevel: json['battery_level'] as int?,
      signalStrength: json['signal_strength'] as int?,
      firmwareVersion: json['firmware_version'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (signalStrength != null) 'signal_strength': signalStrength,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
    };
  }
}

/// Health reading data model (device-based)
class HealthReading {
  final String deviceUid;
  final String deviceType;
  final DateTime timestamp;
  final VitalsData vitals;
  final MetadataData? metadata;
  final ECGData? ecg;
  final DateTime? receivedAt;

  HealthReading({
    required this.deviceUid,
    required this.deviceType,
    required this.timestamp,
    required this.vitals,
    this.metadata,
    this.ecg,
    this.receivedAt,
  });

  // Convenience getters for backward compatibility
  String get deviceId => deviceUid;
  double? get spo2 => vitals.spo2;
  double? get temperature => vitals.temperature;
  int? get heartRate => vitals.heartRate;
  int? get respiratoryRate => vitals.respiratoryRate;
  int? get batteryLevel => metadata?.batteryLevel;
  int? get signalStrength => metadata?.signalStrength;

  factory HealthReading.fromJson(Map<String, dynamic> json) {
    return HealthReading(
      deviceUid: json['device_uid'] as String,
      deviceType: json['device_type'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((json['timestamp'] as num).toDouble() * 1000).toInt(),
      ),
      vitals: VitalsData.fromJson(json['vitals'] as Map<String, dynamic>),
      metadata: json['metadata'] != null
          ? MetadataData.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      ecg: json['ecg'] != null
          ? ECGData.fromJson(json['ecg'] as Map<String, dynamic>)
          : null,
      receivedAt: json['received_at'] != null
          ? DateTime.parse(json['received_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_uid': deviceUid,
      'device_type': deviceType,
      'timestamp': timestamp.millisecondsSinceEpoch / 1000,
      'vitals': vitals.toJson(),
      if (metadata != null) 'metadata': metadata!.toJson(),
      if (ecg != null) 'ecg': ecg!.toJson(),
      if (receivedAt != null) 'received_at': receivedAt!.toIso8601String(),
    };
  }

  /// Get status color based on thresholds
  HealthStatus get status {
    if (spo2 != null && spo2! < 85.0) return HealthStatus.critical;
    if (heartRate != null && (heartRate! < 40 || heartRate! > 150)) {
      return HealthStatus.critical;
    }
    if (temperature != null && temperature! > 39.5) {
      return HealthStatus.critical;
    }

    if (spo2 != null && spo2! < 90.0) return HealthStatus.warning;
    if (heartRate != null && (heartRate! < 50 || heartRate! > 120)) {
      return HealthStatus.warning;
    }
    if (temperature != null && (temperature! > 38.0 || temperature! < 35.5)) {
      return HealthStatus.warning;
    }
    if (respiratoryRate != null &&
        (respiratoryRate! < 10 || respiratoryRate! > 25)) {
      return HealthStatus.warning;
    }

    return HealthStatus.normal;
  }
}

/// Health status enum
enum HealthStatus { normal, warning, critical }
