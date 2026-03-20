import 'package:eldercare_app/src/core/app_strings.dart';

class AppValidators {
  AppValidators._();

  static String normalizePhoneNumber(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), '');
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
