import 'package:flutter/material.dart';

import 'package:eldercare_app/src/features/admin/admin_device_registration_page.dart';
import 'package:eldercare_app/src/features/auth/register_page.dart';
import 'package:eldercare_app/src/features/devices/claim_device_page.dart';
import 'package:eldercare_app/src/features/devices/device_thresholds_page.dart';
import 'package:eldercare_app/src/features/ecg/ecg_page.dart';
import 'package:eldercare_app/src/features/navigation/app_root_page.dart';
import 'package:eldercare_app/src/features/navigation/main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const home = '/home';
  static const devices = '/devices';
  static const register = '/register';
  static const history = '/history';
  static const alerts = '/alerts';
  static const account = '/account';
  static const ecg = '/ecg';
  static const claimDevice = '/devices/claim';
  static const deviceThresholds = '/device-thresholds';
  static const adminDeviceRegister = '/admin/devices/register';

  static final routes = <String, WidgetBuilder>{
    root: (_) => const AppRootPage(),
    home: (_) => const AppRootPage(initialTab: MainTab.home),
    devices: (_) => const AppRootPage(initialTab: MainTab.devices),
    register: (_) => const RegisterPage(),
    history: (_) => const AppRootPage(initialTab: MainTab.history),
    alerts: (_) => const AppRootPage(initialTab: MainTab.alerts),
    account: (_) => const AppRootPage(initialTab: MainTab.account),
    ecg: (_) => const ECGPage(),
    claimDevice: (_) => const ClaimDevicePage(),
    deviceThresholds: (_) => const DeviceThresholdsPage(),
    adminDeviceRegister: (_) => const AdminDeviceRegistrationPage(),
  };

  static Route<dynamic> unknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const Scaffold(
        body: Center(
          child: Text('Không tìm thấy trang yêu cầu.'),
        ),
      ),
    );
  }
}
