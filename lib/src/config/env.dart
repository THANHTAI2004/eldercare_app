class Env {
  Env._();

  // API (server api container)
  static const String apiBaseUrl = 'http://159.223.89.90:8080';

  // MQTT (mosquitto)
  static const String mqttHost = '159.223.89.90';
  static const String mqttUsername = 'esp32';
  static const String mqttPassword = 'Thi@200797';

  static const int mqttTcpPort = 1883;   // Android/Windows
  static const int mqttWsPort = 9001;    // Web
  static const String mqttWsPath = '/mqtt';

  // ❗ Không có user mặc định
  static const String defaultUserId = '';
}
