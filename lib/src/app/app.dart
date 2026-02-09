import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/app/theme.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';

class EldercareApp extends StatelessWidget {
  const EldercareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DeviceProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => RealtimeProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Eldercare',

        theme: AppTheme.light,
        darkTheme: AppTheme.dark,

        // ✅ MUỐN NỀN TRẮNG LUÔN -> dùng ThemeMode.light
        themeMode: ThemeMode.light,
        // Nếu muốn tự theo hệ thống thì đổi lại:
        // themeMode: ThemeMode.system,

        home: const DevicePage(),
        routes: AppRoutes.routes,
        onUnknownRoute: AppRoutes.unknownRoute,
      ),
    );
  }
}
