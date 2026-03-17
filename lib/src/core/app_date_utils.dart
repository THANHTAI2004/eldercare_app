import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String? formatDateOfBirth(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }
}
