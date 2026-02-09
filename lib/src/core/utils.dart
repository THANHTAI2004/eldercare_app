import 'dart:convert';

double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? parseTime(dynamic v) {
  if (v == null) return null;

  // ISO string
  if (v is String) {
    final dt = DateTime.tryParse(v);
    if (dt != null) return dt.toUtc();
    // maybe numeric string
    final n = int.tryParse(v);
    if (n != null) return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
    return null;
  }

  // epoch seconds or ms
  if (v is num) {
    final n = v.toInt();
    // nếu quá lớn -> ms
    if (n > 2000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
    }
    // seconds
    return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
  }

  return null;
}

Map<String, dynamic> safeJsonMap(String s) {
  final x = jsonDecode(s);
  if (x is Map<String, dynamic>) return x;
  return <String, dynamic>{};
}
