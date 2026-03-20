import 'dart:convert';

double? toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? parseTime(dynamic value) {
  if (value == null) return null;

  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();

    final number = int.tryParse(value);
    if (number != null) {
      return DateTime.fromMillisecondsSinceEpoch(number * 1000, isUtc: true);
    }
    return null;
  }

  if (value is num) {
    final number = value.toInt();
    if (number > 2000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(number, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(number * 1000, isUtc: true);
  }

  return null;
}

Map<String, dynamic> safeJsonMap(String input) {
  final decoded = jsonDecode(input);
  if (decoded is Map<String, dynamic>) return decoded;
  return <String, dynamic>{};
}
