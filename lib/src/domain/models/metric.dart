enum Metric { hr, spo2, temp, rr, leadOff }

extension MetricX on Metric {
  String get key {
    switch (this) {
      case Metric.hr:
        return 'hr';
      case Metric.spo2:
        return 'spo2';
      case Metric.temp:
        return 'temp';
      case Metric.rr:
        return 'rr';
      case Metric.leadOff:
        return 'leadOff';
    }
  }

  String get label {
    switch (this) {
      case Metric.hr:
        return 'Nhịp tim';
      case Metric.spo2:
        return 'SpO₂';
      case Metric.temp:
        return 'Nhiệt độ';
      case Metric.rr:
        return 'Nhịp thở';
      case Metric.leadOff:
        return 'Lead Off';
    }
  }

  String get unit {
    switch (this) {
      case Metric.hr:
        return 'bpm';
      case Metric.spo2:
        return '%';
      case Metric.temp:
        return '°C';
      case Metric.rr:
        return 'l/p';
      case Metric.leadOff:
        return '';
    }
  }
}
