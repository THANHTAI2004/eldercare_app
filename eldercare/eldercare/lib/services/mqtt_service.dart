import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/config.dart';
import '../models/health_reading.dart';
import '../models/alert_model.dart';

/// MQTT Service for real-time data
class MqttService {
  MqttServerClient? _client;
  final String deviceUid;

  // Streams for broadcasting data
  final _healthStreamController = StreamController<HealthReading>.broadcast();
  final _alertStreamController = StreamController<AlertModel>.broadcast();
  final _connectionStreamController =
      StreamController<MqttConnectionState>.broadcast();

  Stream<HealthReading> get healthStream => _healthStreamController.stream;
  Stream<AlertModel> get alertStream => _alertStreamController.stream;
  Stream<MqttConnectionState> get connectionStream =>
      _connectionStreamController.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  MqttService({required this.deviceUid});

  /// Connect to MQTT broker
  Future<void> connect() async {
    try {
      // Create client with unique ID
      final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient(AppConfig.mqttBrokerHost, clientId);
      _client!.port = AppConfig.mqttBrokerPort;
      _client!.keepAlivePeriod = AppConfig.mqttKeepAlive;
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;
      _client!.logging(on: false);

      // Set up connection message
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMessage;

      // Set up callbacks
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;

      print(
        '🔌 Connecting to MQTT broker at ${AppConfig.mqttBrokerHost}:${AppConfig.mqttBrokerPort}',
      );

      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        print('✅ MQTT Connected');
        _connectionStreamController.add(MqttConnectionState.connected);

        // Subscribe to topics
        _subscribeToTopics();

        // Listen for messages
        _client!.updates!.listen(_onMessage);
      } else {
        print('❌ MQTT Connection failed: ${_client!.connectionStatus}');
        _connectionStreamController.add(MqttConnectionState.disconnected);
      }
    } catch (e) {
      print('❌ MQTT Connection error: $e');
      _connectionStreamController.add(MqttConnectionState.faulted);
      rethrow;
    }
  }

  /// Subscribe to health and alert topics
  void _subscribeToTopics() {
    final healthTopic = AppConfig.getHealthTopic(deviceUid);
    final alertTopic = AppConfig.getAlertTopic(deviceUid);

    print('📡 Subscribing to: $healthTopic');
    _client!.subscribe(healthTopic, MqttQos.atLeastOnce);

    print('📡 Subscribing to: $alertTopic');
    _client!.subscribe(alertTopic, MqttQos.atLeastOnce);
  }

  /// Handle incoming messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );

      try {
        final data = json.decode(payload) as Map<String, dynamic>;

        if (topic == AppConfig.getHealthTopic(deviceUid)) {
          // Parse health reading
          final healthReading = HealthReading.fromJson(data);
          print(
            '📊 New health reading: HR=${healthReading.heartRate}, SpO2=${healthReading.spo2}',
          );
          _healthStreamController.add(healthReading);
        } else if (topic == AppConfig.getAlertTopic(deviceUid)) {
          // Parse alert
          final alert = AlertModel.fromJson(data);
          print('⚠️ Alert [${alert.severity.name}]: ${alert.message}');
          _alertStreamController.add(alert);
        }
      } catch (e) {
        print('❌ Error parsing message from $topic: $e');
      }
    }
  }

  /// Connection callback
  void _onConnected() {
    print('✅ MQTT Connected callback');
    _connectionStreamController.add(MqttConnectionState.connected);
  }

  /// Disconnection callback
  void _onDisconnected() {
    print('⚠️ MQTT Disconnected');
    _connectionStreamController.add(MqttConnectionState.disconnected);
  }

  /// Subscription callback
  void _onSubscribed(String topic) {
    print('✅ Subscribed to: $topic');
  }

  /// Disconnect from MQTT broker
  void disconnect() {
    print('🔌 Disconnecting from MQTT');
    _client?.disconnect();
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _healthStreamController.close();
    _alertStreamController.close();
    _connectionStreamController.close();
  }
}
