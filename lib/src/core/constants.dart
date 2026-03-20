import 'package:eldercare_app/src/domain/models/metric.dart';

class AppConstants {
  AppConstants._();

  static const int liveMaxPoints = 240;
  static const Duration historyLoadDuration = Duration(days: 7);

  static const List<Metric> allMetrics = [
    Metric.hr,
    Metric.spo2,
    Metric.temp,
    Metric.rr,
    Metric.leadOff,
  ];
}
