import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/app/theme.dart';
import 'package:eldercare_app/src/data/api/alerts_api_service.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/auth_api_service.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/data/local/auth_storage.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

class EldercareApp extends StatelessWidget {
  const EldercareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient.fromEnv()),
        Provider<AuthStorage>(create: (_) => AuthStorage()),
        ChangeNotifierProvider(
          create: (context) => SessionProvider(
            client: context.read<ApiClient>(),
            authApi: AuthApiService(
              client: context.read<ApiClient>(),
              storage: context.read<AuthStorage>(),
            ),
          )..bootstrap(),
        ),
        ChangeNotifierProxyProvider<SessionProvider, RealtimeProvider>(
          create: (context) => RealtimeProvider(client: context.read<ApiClient>()),
          update: (context, session, realtime) {
            final provider =
                realtime ??
                RealtimeProvider(client: context.read<ApiClient>());
            provider.handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<SessionProvider, DeviceProvider>(
          create: (context) => DeviceProvider(
            api: DeviceApiService(client: context.read<ApiClient>()),
          )..load(),
          update: (context, session, deviceProvider) {
            final provider =
                deviceProvider ??
                DeviceProvider(
                  api: DeviceApiService(client: context.read<ApiClient>()),
                );
            provider.handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<SessionProvider, HistoryProvider>(
          create: (context) => HistoryProvider(client: context.read<ApiClient>()),
          update: (context, session, historyProvider) {
            final provider =
                historyProvider ??
                HistoryProvider(client: context.read<ApiClient>());
            provider.handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<SessionProvider, EcgProvider>(
          create: (context) => EcgProvider(client: context.read<ApiClient>()),
          update: (context, session, ecgProvider) {
            final provider =
                ecgProvider ?? EcgProvider(client: context.read<ApiClient>());
            provider.handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<SessionProvider, AlertsProvider>(
          create: (context) => AlertsProvider(
            api: AlertsApiService(client: context.read<ApiClient>()),
          ),
          update: (context, session, alertsProvider) {
            final provider =
                alertsProvider ??
                AlertsProvider(
                  api: AlertsApiService(client: context.read<ApiClient>()),
                );
            provider.handleSessionState(
              isAuthenticated: session.isAuthenticated,
              authenticatedUserId: session.authenticatedUserId,
            );
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Eldercare',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const DevicePage(),
        routes: AppRoutes.routes,
        onUnknownRoute: AppRoutes.unknownRoute,
      ),
    );
  }
}
