import 'package:flutter/material.dart';

import 'package:eldercare_app/src/features/alerts/alerts_page.dart';
import 'package:eldercare_app/src/features/history/history_page.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';

class AppRoutes {
  AppRoutes._();

  static const devices = '/devices';
  static const history = '/history';
  static const alerts = '/alerts';

  static final routes = <String, WidgetBuilder>{
    devices: (_) => const DevicePage(),
    history: (_) => const HistoryPage(),
    alerts: (_) => const AlertsPage(),
  };

  static Route<dynamic> unknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(child: Text('Route không tồn tại: ${settings.name}')),
      ),
    );
  }
}
