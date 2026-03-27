import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/data/api/push_token_api_service.dart';
import 'package:eldercare_app/src/data/local/push_installation_storage.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'eldercare_alerts',
  'Eldercare Alerts',
  description: 'High priority alerts for Eldercare devices',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.bootstrap();
  await PushNotificationService.showForegroundNotification(message);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  PushNotificationService.handleNotificationPayload(response.payload);
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService({
    required PushTokenApiService pushTokensApi,
    PushInstallationStorage? installationStorage,
  }) : _pushTokensApi = pushTokensApi,
       _installationStorage = installationStorage ?? PushInstallationStorage() {
    _instance = this;
  }

  static PushNotificationService? _instance;
  static bool _bootstrapAttempted = false;
  static bool _localNotificationsInitialized = false;

  static PushNotificationService? get instance => _instance;

  final PushTokenApiService _pushTokensApi;
  final PushInstallationStorage _installationStorage;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  DeviceProvider? _deviceProvider;
  AlertsProvider? _alertsProvider;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  bool _isInitialized = false;
  bool _firebaseReady = false;
  bool _isAuthenticated = false;
  String _authenticatedUserId = '';
  String? _lastSyncedTokenKey;
  Map<String, dynamic>? _pendingNotificationData;
  bool _pushSyncDisabledByServer = false;

  static Future<void> bootstrap() async {
    if (_bootstrapAttempted) return;
    _bootstrapAttempted = true;

    if (!_supportsPushNotificationsOnCurrentPlatform()) return;

    final ready = await _tryInitializeFirebase();
    if (!ready) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!_supportsPushNotificationsOnCurrentPlatform()) return;

    _firebaseReady = await _tryInitializeFirebase();
    if (!_firebaseReady) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _setupLocalNotifications();
    await _requestNotificationPermissions();

    _onMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _onMessageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
        .listen(_handleOpenedMessage);
    _onTokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen((token) {
          unawaited(_syncPushToken(forcedToken: token));
        });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }

    unawaited(_syncPushToken());
  }

  void bindProviders({
    required DeviceProvider deviceProvider,
    required AlertsProvider alertsProvider,
  }) {
    _deviceProvider = deviceProvider;
    _alertsProvider = alertsProvider;
    unawaited(_flushPendingNotificationRouting());
  }

  void handleSessionState({
    required bool isAuthenticated,
    required String authenticatedUserId,
  }) {
    _isAuthenticated = isAuthenticated;
    _authenticatedUserId = authenticatedUserId.trim();
    if (!_isAuthenticated) {
      _lastSyncedTokenKey = null;
      return;
    }
    unawaited(_syncPushToken());
  }

  Future<void> unregisterCurrentInstallation() async {
    if (!_firebaseReady) return;

    try {
      final installationId = await _installationStorage.getOrCreateInstallationId(
        platform: _platformLabel(),
      );
      await _pushTokensApi.deletePushToken(installationId: installationId);
      _lastSyncedTokenKey = null;
    } on PushTokenEndpointUnsupportedException catch (e) {
      _pushSyncDisabledByServer = true;
      debugPrint('[PushNotificationService] Push token unregister skipped: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Push token unregister skipped: $e');
    }
  }

  static Future<void> showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb || !_supportsPushNotificationsOnCurrentPlatform()) return;
    await _setupLocalNotifications();

    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString().trim();
    final body = notification?.body ?? message.data['body']?.toString().trim();

    if ((title ?? '').isEmpty && (body ?? '').isEmpty) return;

    await _localNotificationsPlugin.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _alertsChannel.id,
          _alertsChannel.name,
          channelDescription: _alertsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void handleNotificationPayload(String? payload) {
    final service = _instance;
    if (service == null || payload == null || payload.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        service._pendingNotificationData = decoded;
      } else if (decoded is Map) {
        service._pendingNotificationData = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      service._pendingNotificationData = const <String, dynamic>{};
    }

    unawaited(service._flushPendingNotificationRouting());
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await showForegroundNotification(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _pendingNotificationData = Map<String, dynamic>.from(message.data);
    unawaited(_flushPendingNotificationRouting());
  }

  Future<void> _flushPendingNotificationRouting() async {
    final data = _pendingNotificationData;
    final navigator = navigatorKey.currentState;
    final deviceProvider = _deviceProvider;
    final alertsProvider = _alertsProvider;
    if (data == null ||
        navigator == null ||
        deviceProvider == null ||
        alertsProvider == null) {
      return;
    }

    _pendingNotificationData = null;

    final deviceId = _readDeviceId(data);
    if (deviceId.isNotEmpty) {
      alertsProvider.bindDevice(deviceId);
      final device = deviceProvider.findById(deviceId);
      if (device != null) {
        await deviceProvider.setCurrent(device.id);
      }
    }

    await alertsProvider.loadAlerts();
    navigator.pushNamed(AppRoutes.alerts);
  }

  Future<void> _syncPushToken({String? forcedToken}) async {
    if (!_firebaseReady ||
        !_isAuthenticated ||
        _authenticatedUserId.isEmpty ||
        _pushSyncDisabledByServer) {
      return;
    }

    try {
      final installationId = await _installationStorage.getOrCreateInstallationId(
        platform: _platformLabel(),
      );
      final token =
          forcedToken?.trim() ??
          (await FirebaseMessaging.instance.getToken())?.trim() ??
          '';
      if (token.isEmpty) return;

      final syncKey = '$_authenticatedUserId::$installationId::$token';
      if (_lastSyncedTokenKey == syncKey) return;

      await _pushTokensApi.registerPushToken(
        installationId: installationId,
        fcmToken: token,
        platform: _platformLabel(),
      );
      _lastSyncedTokenKey = syncKey;
    } on PushTokenEndpointUnsupportedException catch (e) {
      _pushSyncDisabledByServer = true;
      debugPrint('[PushNotificationService] Push token sync disabled: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Token sync skipped: $e');
    }
  }

  static Future<bool> _tryInitializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return true;
    } catch (e) {
      debugPrint('[PushNotificationService] Firebase init skipped: $e');
      return false;
    }
  }

  static Future<void> _setupLocalNotifications() async {
    if (_localNotificationsInitialized || kIsWeb) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationPayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_alertsChannel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    _localNotificationsInitialized = true;
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Permission request skipped: $e');
    }
  }

  static bool _supportsPushNotificationsOnCurrentPlatform() {
    if (kIsWeb) return true;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  static String _readDeviceId(Map<String, dynamic> data) {
    final candidates = <dynamic>[
      data['device_id'],
      data['deviceId'],
      data['device'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  @override
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedSubscription?.cancel();
    _onTokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
