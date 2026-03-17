import 'package:eldercare_app/src/core/app_strings.dart';

class AppValidators {
  AppValidators._();

  static String? validatePhoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return AppStrings.loginPhoneRequired;
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    final phoneRegex = RegExp(r'^(0|\+84)[0-9]{9,10}$');
    if (!phoneRegex.hasMatch(normalized)) {
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
