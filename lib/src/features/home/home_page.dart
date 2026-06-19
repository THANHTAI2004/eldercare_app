import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/features/ecg/ecg_page.dart';
import 'package:eldercare_app/src/features/history/history_page.dart';
import 'package:eldercare_app/src/features/navigation/main_shell.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/alert_card.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/device_selector.dart';
import 'package:eldercare_app/src/ui/components/ecg_waveform_card.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/health_chart_card.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';
import 'package:eldercare_app/src/ui/components/section_header.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastScopeKey;

  void _syncScope() {
    final session = context.read<SessionProvider>();
    final device = context.read<DeviceProvider>().current;
    final deviceId = device?.resolvedDeviceId ?? '';
    final nextScopeKey = '${session.authenticatedUserId}::$deviceId';
    if (_lastScopeKey == nextScopeKey) return;
    _lastScopeKey = nextScopeKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final realtime = context.read<RealtimeProvider>();
      final history = context.read<HistoryProvider>();
      final ecg = context.read<EcgProvider>();
      final alerts = context.read<AlertsProvider>();
      final today = _todayLocal();

      await realtime.init(deviceId: deviceId);
      await history.bindScope(deviceId: deviceId, dayLocal: today, load: true);
      ecg.bindScope(deviceId: deviceId);
      await ecg.refreshLatest(silent: true);
      await ecg.loadHistoryForDay(today);
      alerts.bindDevice(deviceId);
      await alerts.loadAlerts();
    });
  }

  Future<void> _selectDevice(String? deviceId) async {
    final selectedId = deviceId?.trim() ?? '';
    if (selectedId.isEmpty) return;

    final deviceProvider = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final alerts = context.read<AlertsProvider>();

    await deviceProvider.setCurrent(selectedId);
    final current = deviceProvider.current;
    if (current == null) return;

    final resolvedId = current.resolvedDeviceId;
    await realtime.changeDevice(resolvedId);
    await history.bindScope(
      deviceId: resolvedId,
      dayLocal: _todayLocal(),
      load: true,
    );
    ecg.bindScope(deviceId: resolvedId);
    await ecg.refreshLatest(silent: true);
    await ecg.loadHistoryForDay(_todayLocal());
    alerts.bindDevice(resolvedId);
    await alerts.loadAlerts();
  }

  Future<void> _refreshAll() async {
    final realtime = context.read<RealtimeProvider>();
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final alerts = context.read<AlertsProvider>();
    await realtime.refreshLatest();
    await history.loadForDay(_todayLocal());
    await ecg.refreshLatest();
    await ecg.loadHistoryForDay(_todayLocal());
    await alerts.loadAlerts();
  }

  double? _metricValue(Metric metric) {
    final realtime = context.read<RealtimeProvider>();
    final history = context.read<HistoryProvider>();
    final realtimeValue = realtime.latest?.valueOf(metric);
    if (realtimeValue != null && realtimeValue.isFinite) {
      return realtimeValue;
    }

    final fallback = history.points.reversed
        .map((point) => point.valueOf(metric))
        .whereType<double>()
        .where((value) => value.isFinite)
        .cast<double?>()
        .firstWhere((value) => value != null, orElse: () => null);
    return fallback;
  }

  List<VitalPoint> _pointsForLastHour(HistoryProvider history) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final points = history.points
        .where((point) => point.time.toUtc().isAfter(cutoff))
        .toList(growable: false);
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  Future<void> _openHistory({Metric? metric}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryPage(initialMetric: metric)),
    );
  }

  Future<void> _openEcg() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ECGPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final realtime = context.watch<RealtimeProvider>();
    final history = context.watch<HistoryProvider>();
    final ecg = context.watch<EcgProvider>();
    final alerts = context.watch<AlertsProvider>();
    final currentDevice = deviceProvider.current;
    final currentUserName = session.currentUser?.name.trim() ?? '';
    final oneHourPoints = _pointsForLastHour(history);

    _syncScope();

    if (currentDevice == null) {
      return AppScaffold(
        title: 'Trang chủ',
        subtitle: 'Theo dõi nhanh tình trạng người thân theo thời gian thực.',
        actions: [
          IconButton(
            onPressed: deviceProvider.isSyncing ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        child: ListView(
          children: [
            EmptyState(
              icon: Icons.watch_off_outlined,
              title: 'Bạn chưa chọn thiết bị theo dõi',
              message:
                  'Liên kết hoặc chọn một thiết bị để xem chỉ số realtime, ECG và cảnh báo gần đây.',
              actionLabel: 'Mở màn thiết bị',
              onAction: () =>
                  MainShell.maybeOf(context)?.goToTab(MainTab.devices),
            ),
          ],
        ),
      );
    }

    final overallStatus = _overallStatus(
      hr: _metricValue(Metric.hr),
      spo2: _metricValue(Metric.spo2),
      temp: _metricValue(Metric.temp),
      rr: _metricValue(Metric.rr),
      hasCriticalAlert: alerts.items.any(
        (item) => !item.acknowledged && item.isHighSeverity,
      ),
      leadOff: realtime.latest?.leadOff == 1,
    );

    return AppScaffold(
      title: currentUserName.isEmpty
          ? 'Xin chào'
          : 'Xin chào, $currentUserName',
      subtitle:
          'Theo dõi nhanh 3 chỉ số chính trong 1 giờ gần nhất và trạng thái ECG.',
      actions: [
        IconButton(
          onPressed: realtime.isLoadingLatest ? null : _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            DeviceSelector(
              devices: deviceProvider.devices,
              currentDeviceId: currentDevice.id,
              onChanged: _selectDevice,
              onOpenDevices: () =>
                  MainShell.maybeOf(context)?.goToTab(MainTab.devices),
              isBusy: deviceProvider.isSyncing,
            ),
            const SizedBox(height: AppSpacing.xl),
            _OverviewBanner(status: overallStatus),
            const SizedBox(height: AppSpacing.section),
            SectionHeader(
              title: 'Biểu đồ 1 giờ gần nhất',
              subtitle:
                  'Ẩn nhịp thở và tập trung vào 3 chỉ số quan trọng nhất.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if ((realtime.isLoadingLatest || history.status.isLoading) &&
                history.points.isEmpty)
              const LoadingState(
                message: 'Đang tải dữ liệu sức khỏe 1 giờ gần nhất...',
              )
            else ...[
              _MetricTrendChart(
                title: 'Nhịp tim',
                metric: Metric.hr,
                points: oneHourPoints,
                currentValue: _metricValue(Metric.hr),
                subtitle:
                    'Biểu đồ đường trong 1 giờ gần nhất cho nhịp tim.',
                onOpenHistory: () => _openHistory(metric: Metric.hr),
              ),
              const SizedBox(height: AppSpacing.lg),
              _MetricTrendChart(
                title: 'SpO2',
                metric: Metric.spo2,
                points: oneHourPoints,
                currentValue: _metricValue(Metric.spo2),
                subtitle:
                    'Biểu đồ đường trong 1 giờ gần nhất cho nồng độ oxy máu.',
                onOpenHistory: () => _openHistory(metric: Metric.spo2),
              ),
              const SizedBox(height: AppSpacing.lg),
              _MetricTrendChart(
                title: 'Nhiệt độ',
                metric: Metric.temp,
                points: oneHourPoints,
                currentValue: _metricValue(Metric.temp),
                subtitle:
                    'Biểu đồ đường trong 1 giờ gần nhất cho nhiệt độ cơ thể.',
                onOpenHistory: () => _openHistory(metric: Metric.temp),
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            _EcgOverviewSection(
              ecg: ecg,
              onOpenEcg: _openEcg,
            ),
            const SizedBox(height: AppSpacing.section),
            _RecentAlertsSection(
              onSeeAll: () =>
                  MainShell.maybeOf(context)?.goToTab(MainTab.alerts),
              onAcknowledge: (alertId) =>
                  context.read<AlertsProvider>().acknowledge(alertId),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTrendChart extends StatelessWidget {
  const _MetricTrendChart({
    required this.title,
    required this.metric,
    required this.points,
    required this.currentValue,
    required this.subtitle,
    required this.onOpenHistory,
  });

  final String title;
  final Metric metric;
  final List<VitalPoint> points;
  final double? currentValue;
  final String subtitle;
  final Future<void> Function() onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final valueText = _displayMetric(metric, currentValue);
    final unitText = _metricUnit(metric);

    return HealthChartCard(
      title: title,
      subtitle: 'Hiện tại: $valueText $unitText • $subtitle',
      metric: metric,
      points: points,
      height: 160,
      actionLabel: 'Chi tiết',
      onAction: () => onOpenHistory(),
      emptyMessage: 'Chưa có dữ liệu trong 1 giờ gần nhất',
    );
  }
}

class _EcgOverviewSection extends StatelessWidget {
  const _EcgOverviewSection({
    required this.ecg,
    required this.onOpenEcg,
  });

  final EcgProvider ecg;
  final Future<void> Function() onOpenEcg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Trạng thái ECG',
          subtitle: 'Thay cho xu hướng 24 giờ, hiển thị bản ghi ECG gần nhất.',
          actionLabel: 'Mở ECG',
          onAction: () => onOpenEcg(),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (ecg.isLoading && ecg.latest == null)
          const LoadingState(message: 'Đang tải trạng thái ECG...')
        else if (ecg.latest == null || !ecg.latest!.hasWaveform)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusBadge(
                  label: 'Chưa có bản ghi ECG',
                  tone: StatusTone.neutral,
                  icon: Icons.monitor_heart_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Thiết bị hiện chưa gửi bản ghi ECG có thể hiển thị trên trang chủ.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          ECGWaveformCard(
            reading: ecg.latest!,
            title: 'Bản ghi ECG gần nhất',
          ),
      ],
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  const _OverviewBanner({required this.status});

  final _OverviewStatus status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: status.background,
      borderColor: status.border,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: status.iconBackground,
            child: Icon(status.icon, color: status.iconColor),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tình trạng tổng quan: ${status.label}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: status.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: status.textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAlertsSection extends StatelessWidget {
  const _RecentAlertsSection({
    required this.onSeeAll,
    required this.onAcknowledge,
  });

  final VoidCallback onSeeAll;
  final Future<void> Function(String alertId) onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsProvider>().items.take(2).toList();
    final device = context.watch<DeviceProvider>().current;
    if (alerts.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Cảnh báo gần đây',
              subtitle: 'Hiện chưa có cảnh báo mới cho thiết bị này.',
              actionLabel: 'Xem tất cả',
              onAction: onSeeAll,
            ),
            const SizedBox(height: AppSpacing.lg),
            const StatusBadge(
              label: 'Không có cảnh báo mới',
              tone: StatusTone.success,
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SectionHeader(
          title: 'Cảnh báo gần đây',
          subtitle: 'Ưu tiên cảnh báo mới và chưa xử lý.',
          actionLabel: 'Xem tất cả',
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpacing.lg),
        ...alerts.map(
          (alert) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AppAlertCard(
              alert: alert,
              deviceLabel: device?.name,
              canAcknowledge: device?.isOwnerLink == true,
              onDetails: onSeeAll,
              onAcknowledge: () => onAcknowledge(alert.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewStatus {
  const _OverviewStatus({
    required this.label,
    required this.message,
    required this.icon,
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.textColor,
  });

  final String label;
  final String message;
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final Color textColor;
}

_OverviewStatus _overallStatus({
  required double? hr,
  required double? spo2,
  required double? temp,
  required double? rr,
  required bool hasCriticalAlert,
  required bool leadOff,
}) {
  if (hasCriticalAlert || leadOff || (spo2 != null && spo2 < 90)) {
    return const _OverviewStatus(
      label: 'Nguy hiểm',
      message: 'Cần kiểm tra ngay cảnh báo và tình trạng tiếp xúc thiết bị.',
      icon: Icons.error_outline_rounded,
      background: Color(0xFFFFF1F2),
      border: Color(0xFFFECDD3),
      iconBackground: Color(0xFFFEE2E2),
      iconColor: AppColors.danger,
      textColor: Color(0xFF991B1B),
    );
  }

  final warning =
      (hr != null && (hr < 50 || hr > 110)) ||
      (spo2 != null && spo2 < 94) ||
      (temp != null && temp >= 37.8) ||
      (rr != null && (rr < 12 || rr > 24));

  if (warning) {
    return const _OverviewStatus(
      label: 'Cần chú ý',
      message: 'Một số chỉ số đang chạm ngưỡng cần theo dõi sát hơn.',
      icon: Icons.warning_amber_rounded,
      background: Color(0xFFFFFBEB),
      border: Color(0xFFFDE68A),
      iconBackground: Color(0xFFFEF3C7),
      iconColor: AppColors.warning,
      textColor: Color(0xFF92400E),
    );
  }

  return const _OverviewStatus(
    label: 'Ổn định',
    message: 'Các chỉ số chính đang nằm trong ngưỡng theo dõi an toàn.',
    icon: Icons.check_circle_outline_rounded,
    background: Color(0xFFF0FDF4),
    border: Color(0xFFBBF7D0),
    iconBackground: Color(0xFFDCFCE7),
    iconColor: AppColors.success,
    textColor: Color(0xFF166534),
  );
}

String _displayMetric(Metric metric, double? value) {
  if (value == null || !value.isFinite) return '--';
  if (metric == Metric.temp) {
    return value.toStringAsFixed(1);
  }
  return value.round().toString();
}

String _metricUnit(Metric metric) {
  switch (metric) {
    case Metric.hr:
      return 'bpm';
    case Metric.spo2:
      return '%';
    case Metric.temp:
      return '°C';
    case Metric.rr:
      return '/phút';
    case Metric.leadOff:
      return '';
  }
}

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
