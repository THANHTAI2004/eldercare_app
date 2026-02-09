import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_types.dart';

class MqttService {
  MqttService({
    required this.host,
    required this.username,
    required this.password,
    this.clientId,
    this.tcpPort = 1883,
    this.wsPort = 9001, // ignored on IO
    this.wsPath = '/mqtt', // ignored on IO
    this.keepAliveSeconds = 30,
  });

  final String host;
  final String username;
  final String password;
  String? clientId;

  final int tcpPort;
  final int wsPort;
  final String wsPath;
  final int keepAliveSeconds;

  MqttClient? _client;

  final _messagesCtrl = StreamController<MqttRxMessage>.broadcast();
  Stream<MqttRxMessage> get messages => _messagesCtrl.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  String _genClientId() => 'eldercare_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> connect({String? clientId}) async {
    this.clientId = clientId ?? this.clientId ?? _genClientId();
    if (_client != null && isConnected) return;

    final client = MqttServerClient(host, this.clientId!);
    client.port = tcpPort;
    client.secure = false;

    client.logging(on: false);
    client.keepAlivePeriod = keepAliveSeconds;
    client.setProtocolV311();
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(this.clientId!)
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await client.connect();
    } catch (e) {
      client.disconnect();
      rethrow;
    }

    client.updates?.listen((events) {
      for (final event in events) {
        final rec = event.payload as MqttPublishMessage;
        final payload =
        MqttPublishPayload.bytesToStringAsString(rec.payload.message);
        _messagesCtrl.add(MqttRxMessage(event.topic, payload));
      }
    });

    _client = client;
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    _client?.subscribe(topic, qos);
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesCtrl.close();
  }
}
