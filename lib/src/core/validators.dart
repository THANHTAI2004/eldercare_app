import 'package:eldercare_app/src/core/app_strings.dart';

class AppValidators {
  AppValidators._();

  static String stripPhoneNumberFormatting(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), '');
  }

  static String normalizePhoneNumber(String? value) {
    final raw = stripPhoneNumberFormatting(value);
    if (raw.isEmpty) return raw;
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('84') && raw.length >= 11) {
      return '+$raw';
    }
    if (raw.startsWith('0') && raw.length >= 10) {
      return '+84${raw.substring(1)}';
    }
    return raw;
  }

  static List<String> loginPhoneCandidates(String? value) {
    final raw = stripPhoneNumberFormatting(value);
    if (raw.isEmpty) return const <String>[];

    final candidates = <String>[];

    void addCandidate(String phoneNumber) {
      final trimmed = phoneNumber.trim();
      if (trimmed.isEmpty || candidates.contains(trimmed)) return;
      candidates.add(trimmed);
    }

    addCandidate(normalizePhoneNumber(raw));
    addCandidate(raw);

    if (raw.startsWith('+84') && raw.length > 3) {
      addCandidate('0${raw.substring(3)}');
    } else if (raw.startsWith('84') && raw.length > 2) {
      addCandidate('0${raw.substring(2)}');
    } else if (raw.startsWith('0') && raw.length >= 10) {
      addCandidate('+84${raw.substring(1)}');
    }

    return candidates;
  }

  static String? validatePhoneNumber(String? value) {
    final text = normalizePhoneNumber(value);
    if (text.isEmpty) return AppStrings.loginPhoneRequired;
    final phoneRegex = RegExp(r'^(0|\+84)[0-9]{9,10}$');
    if (!phoneRegex.hasMatch(text)) {
      return AppStrings.phoneInvalid;
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return AppStrings.loginPasswordRequired;
    if (text.length < 8) return AppStrings.passwordTooShort;
    return null;
  }
}
