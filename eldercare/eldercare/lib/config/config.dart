/// Configuration constants for the Eldercare app
class AppConfig {
  // Server Configuration
  static const String apiBaseUrl = 'http://172.26.135.230:8000';
  static const String mqttBrokerHost = '172.26.135.230';
  static const int mqttBrokerPort = 1883;

  // Device Configuration
  static const String defaultDeviceUid = 'ESP32_A1B2C3D4E5F6';

  // MQTT Topics (device-based)
  static String getHealthTopic(String deviceUid) => 'health/devices/$deviceUid';
  static String getAlertTopic(String deviceUid) => 'alerts/devices/$deviceUid';

  // API Endpoints (device-based)
  static String getLatestEndpoint(String deviceUid) =>
      '/api/v1/devices/$deviceUid/latest';
  static String getVitalsEndpoint(String deviceUid) =>
      '/api/v1/devices/$deviceUid/vitals';
  static String getECGEndpoint(String deviceUid) =>
      '/api/v1/devices/$deviceUid/ecg';
  static String getSummaryEndpoint(String deviceUid) =>
      '/api/v1/devices/$deviceUid/summary';
  static String getAlertsEndpoint(String deviceUid) =>
      '/api/v1/devices/$deviceUid/alerts';
  static const String registerDeviceEndpoint = '/api/v1/devices/register';

  // App Settings
  static const int defaultVitalsLimit = 100;
  static const int mqttKeepAlive = 60;
  static const int mqttReconnectDelay = 5000; // milliseconds

  // Thresholds (default values)
  static const double spo2LowWarning = 90.0;
  static const double spo2LowCritical = 85.0;
  static const double tempHighWarning = 38.0;
  static const double tempHighCritical = 39.5;
  static const double tempLowWarning = 35.5;
  static const int hrLowWarning = 50;
  static const int hrLowCritical = 40;
  static const int hrHighWarning = 120;
  static const int hrHighCritical = 150;
  static const int rrLowWarning = 10;
  static const int rrHighWarning = 25;
}
