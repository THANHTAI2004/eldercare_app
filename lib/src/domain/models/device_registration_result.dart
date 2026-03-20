class DeviceRegistrationResult {
  const DeviceRegistrationResult({
    required this.status,
    required this.deviceId,
    required this.pairingCode,
  });

  final String status;
  final String deviceId;
  final String pairingCode;

  factory DeviceRegistrationResult.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResult(
      status: _readString(json['status']) ?? '',
      deviceId:
          _readString(json['device_id']) ??
          _readString(json['deviceId']) ??
          '',
      pairingCode:
          _readString(json['pairing_code']) ??
          _readString(json['pairingCode']) ??
          '',
    );
  }
}

String? _readString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
