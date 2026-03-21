import 'package:flutter/material.dart';

import 'package:eldercare_app/src/features/account/account_page.dart';
import 'package:eldercare_app/src/features/admin/admin_device_registration_page.dart';
import 'package:eldercare_app/src/features/alerts/alerts_page.dart';
import 'package:eldercare_app/src/features/auth/register_page.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/features/history/history_page.dart';

class AppRoutes {
  AppRoutes._();

  static const devices = '/devices';
  static const register = '/register';
  static const history = '/history';
  static const alerts = '/alerts';
  static const account = '/account';
  static const adminDeviceRegister = '/admin/devices/register';

  static final routes = <String, WidgetBuilder>{
    devices: (_) => const DevicePage(),
    register: (_) => const RegisterPage(),
    history: (_) => const HistoryPage(),
    alerts: (_) => const AlertsPage(),
    account: (_) => const AccountPage(),
    adminDeviceRegister: (_) => const AdminDeviceRegistrationPage(),
  };

  static Route<dynamic> unknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(child: Text('Đường dẫn không tồn tại: ${settings.name}')),
      ),
    );
  }
}
