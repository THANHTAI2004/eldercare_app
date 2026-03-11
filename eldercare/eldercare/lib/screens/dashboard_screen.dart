import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../config/config.dart';
import '../models/health_reading.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import '../widgets/vital_sign_card.dart';
import '../widgets/ecg_chart.dart';
import '../widgets/connection_indicator.dart';

/// Dashboard screen for real-time health monitoring
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late MqttService _mqttService;
  late ApiService _apiService;

  HealthReading? _latestReading;
  bool _isApiConnected = false;
  MqttConnectionState? _mqttState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _mqttService = MqttService(deviceUid: AppConfig.defaultDeviceUid);
    _initialize();
  }

  Future<void> _initialize() async {
    // Check API connection
    _isApiConnected = await _apiService.healthCheck();

    // Fetch latest data from API
    if (_isApiConnected) {
      try {
        final vitals = await _apiService.getVitals(
          deviceUid: AppConfig.defaultDeviceUid,
          limit: 1,
        );
        if (vitals.isNotEmpty && mounted) {
          setState(() {
            _latestReading = vitals.first;
          });
        }
      } catch (e) {
        print('Error fetching vitals: $e');
      }
    }

    // Connect to MQTT
    try {
      await _mqttService.connect();

      // Listen to connection changes
      _mqttService.connectionStream.listen((state) {
        if (mounted) {
          setState(() {
            _mqttState = state;
          });
        }
      });

      // Listen to health data updates
      _mqttService.healthStream.listen((reading) {
        if (mounted) {
          setState(() {
            _latestReading = reading;
          });
        }
      });
    } catch (e) {
      print('MQTT connection error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      _isApiConnected = await _apiService.healthCheck();

      if (_isApiConnected) {
        final vitals = await _apiService.getVitals(
          deviceUid: AppConfig.defaultDeviceUid,
          limit: 1,
        );
        if (vitals.isNotEmpty && mounted) {
          setState(() {
            _latestReading = vitals.first;
          });
        }
      }
    } catch (e) {
      print('Error refreshing: $e');
    }
  }

  @override
  void dispose() {
    _mqttService.dispose();
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Giám sát sức khỏe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ConnectionIndicator(
              isApiConnected: _isApiConnected,
              mqttState: _mqttState,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient info
                    _buildPatientInfo(),
                    const SizedBox(height: 20),

                    // Vital signs grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        VitalSignCard(
                          title: 'SpO2',
                          value: _latestReading?.spo2?.toStringAsFixed(1),
                          unit: '%',
                          icon: Icons.air,
                          status: _getSpO2Status(),
                        ),
                        VitalSignCard(
                          title: 'Nhịp tim',
                          value: _latestReading?.heartRate?.toString(),
                          unit: 'BPM',
                          icon: Icons.favorite,
                          status: _getHeartRateStatus(),
                        ),
                        VitalSignCard(
                          title: 'Nhịp thở',
                          value: _latestReading?.respiratoryRate?.toString(),
                          unit: '/phút',
                          icon: Icons.waves,
                          status: _getRespiratoryStatus(),
                        ),
                        VitalSignCard(
                          title: 'Nhiệt độ',
                          value: _latestReading?.temperature?.toStringAsFixed(
                            1,
                          ),
                          unit: '°C',
                          icon: Icons.thermostat,
                          status: _getTemperatureStatus(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ECG Chart
                    if (_latestReading?.ecg != null)
                      EcgChart(
                        waveform: _latestReading!.ecg!.waveform,
                        heartRate: _latestReading?.heartRate,
                        quality: _latestReading!.ecg!.quality,
                      )
                    else
                      _buildNoEcgCard(),

                    const SizedBox(height: 20),

                    // Last update time
                    if (_latestReading != null)
                      Center(
                        child: Text(
                          'Cập nhật lần cuối: ${_formatTime(_latestReading!.timestamp)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.devices_other,
                size: 30,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device ID',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConfig.defaultDeviceUid,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_latestReading?.batteryLevel != null)
              Row(
                children: [
                  Icon(
                    Icons.battery_std,
                    color: _getBatteryColor(_latestReading!.batteryLevel!),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_latestReading!.batteryLevel}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getBatteryColor(_latestReading!.batteryLevel!),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEcgCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Không có dữ liệu ECG',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  HealthStatus _getSpO2Status() {
    if (_latestReading?.spo2 == null) return HealthStatus.normal;
    if (_latestReading!.spo2! < AppConfig.spo2LowCritical) {
      return HealthStatus.critical;
    }
    if (_latestReading!.spo2! < AppConfig.spo2LowWarning) {
      return HealthStatus.warning;
    }
    return HealthStatus.normal;
  }

  HealthStatus _getHeartRateStatus() {
    if (_latestReading?.heartRate == null) return HealthStatus.normal;
    final hr = _latestReading!.heartRate!;
    if (hr < AppConfig.hrLowCritical || hr > AppConfig.hrHighCritical) {
      return HealthStatus.critical;
    }
    if (hr < AppConfig.hrLowWarning || hr > AppConfig.hrHighWarning) {
      return HealthStatus.warning;
    }
    return HealthStatus.normal;
  }

  HealthStatus _getRespiratoryStatus() {
    if (_latestReading?.respiratoryRate == null) return HealthStatus.normal;
    final rr = _latestReading!.respiratoryRate!;
    if (rr < AppConfig.rrLowWarning || rr > AppConfig.rrHighWarning) {
      return HealthStatus.warning;
    }
    return HealthStatus.normal;
  }

  HealthStatus _getTemperatureStatus() {
    if (_latestReading?.temperature == null) return HealthStatus.normal;
    final temp = _latestReading!.temperature!;
    if (temp > AppConfig.tempHighCritical) {
      return HealthStatus.critical;
    }
    if (temp > AppConfig.tempHighWarning || temp < AppConfig.tempLowWarning) {
      return HealthStatus.warning;
    }
    return HealthStatus.normal;
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} giây trước';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
