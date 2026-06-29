import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/alert_item.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
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
import 'package:eldercare_app/src/ui/components/metric_value_card.dart';
import 'package:eldercare_app/src/ui/components/responsive_grid.dart';
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
      hasCriticalAlert: alerts.items.any(
        (item) => !item.acknowledged && item.isHighSeverity,
      ),
      hasFallAlert: alerts.items.any(
        (item) =>
            !item.acknowledged &&
            item.alertType?.toLowerCase() == 'fall_detected',
      ),
      leadOff: realtime.latest?.leadOff == 1,
    );

    return AppScaffold(
      title: currentUserName.isEmpty
          ? 'Xin chào'
          : 'Xin chào, $currentUserName',
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
            _DeviceStatusHeader(
              device: currentDevice,
              devices: deviceProvider.devices,
              isOnline: realtime.hasDevice ? realtime.isOnline : null,
              isBusy: deviceProvider.isSyncing,
              onChanged: _selectDevice,
              onOpenDevices: () =>
                  MainShell.maybeOf(context)?.goToTab(MainTab.devices),
            ),
            const SizedBox(height: AppSpacing.xl),
            _OverviewBanner(
              status: overallStatus,
              onOpenAlerts: () =>
                  MainShell.maybeOf(context)?.goToTab(MainTab.alerts),
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Chỉ số hiện tại'),
            const SizedBox(height: AppSpacing.lg),
            _CurrentVitalsGrid(
              hr: _metricValue(Metric.hr),
              spo2: _metricValue(Metric.spo2),
              temp: _metricValue(Metric.temp),
              leadOff: realtime.latest?.leadOff == 1,
              fallAlerts: alerts.items
                  .where((a) => a.alertType?.toLowerCase() == 'fall_detected')
                  .toList(growable: false),
              onOpenHistory: _openHistory,
              onOpenAlerts: () =>
                  MainShell.maybeOf(context)?.goToTab(MainTab.alerts),
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Biểu đồ 1 giờ gần nhất'),
            const SizedBox(height: AppSpacing.lg),
            if ((realtime.isLoadingLatest || history.status.isLoading) &&
                history.points.isEmpty)
              const LoadingState(
                message: 'Đang tải dữ liệu sức khỏe 1 giờ gần nhất...',
              )
            else
              ResponsiveGrid(
                minItemWidth: 420,
                children: [
                  _MetricTrendChart(
                    title: 'Nhịp tim',
                    metric: Metric.hr,
                    points: oneHourPoints,
                    currentValue: _metricValue(Metric.hr),
                    onOpenHistory: () => _openHistory(metric: Metric.hr),
                  ),
                  _MetricTrendChart(
                    title: 'SpO2',
                    metric: Metric.spo2,
                    points: oneHourPoints,
                    currentValue: _metricValue(Metric.spo2),
                    onOpenHistory: () => _openHistory(metric: Metric.spo2),
                  ),
                  _MetricTrendChart(
                    title: 'Nhiệt độ',
                    metric: Metric.temp,
                    points: oneHourPoints,
                    currentValue: _metricValue(Metric.temp),
                    onOpenHistory: () => _openHistory(metric: Metric.temp),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.section),
            _EcgOverviewSection(ecg: ecg, onOpenEcg: _openEcg),
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

// ---------------------------------------------------------------------------
// _DeviceStatusHeader
// ---------------------------------------------------------------------------

class _DeviceStatusHeader extends StatelessWidget {
  const _DeviceStatusHeader({
    required this.device,
    required this.devices,
    required this.isOnline,
    required this.isBusy,
    required this.onChanged,
    required this.onOpenDevices,
  });

  final Device device;
  final List<Device> devices;
  final bool? isOnline;
  final bool isBusy;
  final ValueChanged<String?> onChanged;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    return DeviceSelector(
      devices: devices,
      currentDeviceId: device.id,
      onChanged: onChanged,
      onOpenDevices: onOpenDevices,
      isBusy: isBusy,
      isOnline: isOnline,
    );
  }
}

// ---------------------------------------------------------------------------
// _CurrentVitalsGrid
// ---------------------------------------------------------------------------

class _CurrentVitalsGrid extends StatelessWidget {
  const _CurrentVitalsGrid({
    required this.hr,
    required this.spo2,
    required this.temp,
    required this.leadOff,
    required this.fallAlerts,
    required this.onOpenHistory,
    required this.onOpenAlerts,
  });

  final double? hr;
  final double? spo2;
  final double? temp;
  final bool leadOff;
  final List<AlertItem> fallAlerts;
  final Future<void> Function({Metric? metric}) onOpenHistory;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: 170,
      children: [
        MetricValueCard(
          title: 'Nhịp tim',
          value: _displayMetric(Metric.hr, hr),
          unit: _metricUnit(Metric.hr),
          icon: Icons.favorite_rounded,
          tone: _metricTone(Metric.hr, hr),
          baseColor: AppColors.primary,
          subtitle: leadOff ? 'Kiểm tra tiếp xúc cảm biến' : null,
          onTap: () => onOpenHistory(metric: Metric.hr),
        ),
        MetricValueCard(
          title: 'SpO2',
          value: _displayMetric(Metric.spo2, spo2),
          unit: _metricUnit(Metric.spo2),
          icon: Icons.bloodtype_outlined,
          tone: _metricTone(Metric.spo2, spo2),
          baseColor: AppColors.secondary,
          onTap: () => onOpenHistory(metric: Metric.spo2),
        ),
        MetricValueCard(
          title: 'Nhiệt độ',
          value: _displayMetric(Metric.temp, temp),
          unit: _metricUnit(Metric.temp),
          icon: Icons.thermostat_rounded,
          tone: _metricTone(Metric.temp, temp),
          baseColor: const Color(0xFF059669), // Emerald 600
          onTap: () => onOpenHistory(metric: Metric.temp),
        ),
        _FallAlertCard(fallAlerts: fallAlerts, onTap: onOpenAlerts),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _FallAlertCard
// ---------------------------------------------------------------------------

class _FallAlertCard extends StatelessWidget {
  const _FallAlertCard({required this.fallAlerts, required this.onTap});

  final List<AlertItem> fallAlerts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAlerts = fallAlerts.isNotEmpty;
    final unacked = fallAlerts.where((a) => !a.acknowledged).length;
    final tone = hasAlerts && unacked > 0
        ? StatusTone.danger
        : StatusTone.success;
    final color = _toneColorForFall(tone);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        backgroundColor: hasAlerts && unacked > 0
            ? AppColors.danger.withValues(alpha: 0.06)
            : null,
        borderColor: hasAlerts && unacked > 0
            ? AppColors.danger.withValues(alpha: 0.25)
            : null,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasAlerts && unacked > 0
                        ? Icons.warning_amber_rounded
                        : Icons.accessibility_new_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: hasAlerts && unacked > 0
                                ? '$unacked'
                                : 'Bình thường',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: color, fontWeight: FontWeight.w800),
                          ),
                          if (hasAlerts && unacked > 0)
                            TextSpan(
                              text: ' chưa xử lý',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: color.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Cảnh báo ngã',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

Color _toneColorForFall(StatusTone tone) {
  switch (tone) {
    case StatusTone.danger:
      return AppColors.danger;
    case StatusTone.success:
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

// ---------------------------------------------------------------------------
// _MetricTrendChart
// ---------------------------------------------------------------------------

class _MetricTrendChart extends StatelessWidget {
  const _MetricTrendChart({
    required this.title,
    required this.metric,
    required this.points,
    required this.currentValue,
    required this.onOpenHistory,
  });

  final String title;
  final Metric metric;
  final List<VitalPoint> points;
  final double? currentValue;
  final Future<void> Function() onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final valueText = _displayMetric(metric, currentValue);
    final unitText = _metricUnit(metric);

    return HealthChartCard(
      title: title,
      subtitle: 'Hiện tại: $valueText $unitText',
      metric: metric,
      points: points,
      height: 160,
      actionLabel: 'Chi tiết',
      onAction: () => onOpenHistory(),
      emptyMessage: 'Chưa có dữ liệu trong 1 giờ gần nhất',
    );
  }
}

// ---------------------------------------------------------------------------
// _EcgOverviewSection
// ---------------------------------------------------------------------------

class _EcgOverviewSection extends StatelessWidget {
  const _EcgOverviewSection({required this.ecg, required this.onOpenEcg});

  final EcgProvider ecg;
  final Future<void> Function() onOpenEcg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Trạng thái ECG',
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
          ECGWaveformCard(reading: ecg.latest!, title: 'Bản ghi ECG gần nhất'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _OverviewBanner
// ---------------------------------------------------------------------------

class _OverviewBanner extends StatelessWidget {
  const _OverviewBanner({required this.status, required this.onOpenAlerts});

  final _OverviewStatus status;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: status.background,
      borderColor: status.border,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: status.iconBackground,
            child: Icon(status.icon, color: status.iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: status.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (status.isDanger) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onOpenAlerts,
              style: TextButton.styleFrom(
                foregroundColor: status.textColor,
                backgroundColor: status.iconBackground,
              ),
              child: const Text('Chi tiết'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RecentAlertsSection
// ---------------------------------------------------------------------------

class _RecentAlertsSection extends StatelessWidget {
  const _RecentAlertsSection({
    required this.onSeeAll,
    required this.onAcknowledge,
  });

  final VoidCallback onSeeAll;
  final Future<void> Function(String alertId) onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final allAlerts = context.watch<AlertsProvider>().items;
    final pendingAlerts = allAlerts
        .where((alert) => !alert.acknowledged)
        .take(2)
        .toList(growable: false);
    final alerts = pendingAlerts.isNotEmpty
        ? pendingAlerts
        : allAlerts.take(2).toList(growable: false);
    final device = context.watch<DeviceProvider>().current;
    if (alerts.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Cảnh báo gần đây',
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
              compact: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _OverviewStatus
// ---------------------------------------------------------------------------

class _OverviewStatus {
  const _OverviewStatus({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.textColor,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final Color textColor;
  final bool isDanger;
}

_OverviewStatus _overallStatus({
  required double? hr,
  required double? spo2,
  required double? temp,
  required bool hasCriticalAlert,
  required bool hasFallAlert,
  required bool leadOff,
}) {
  if (hasCriticalAlert ||
      hasFallAlert ||
      leadOff ||
      (spo2 != null && spo2 < 90)) {
    return const _OverviewStatus(
      label: 'Có cảnh báo nguy hiểm cần kiểm tra',
      icon: Icons.error_outline_rounded,
      background: Color(0xFFFFF1F2),
      border: Color(0xFFFECDD3),
      iconBackground: Color(0xFFFEE2E2),
      iconColor: AppColors.danger,
      textColor: Color(0xFF991B1B),
      isDanger: true,
    );
  }

  final warning =
      (hr != null && (hr < 50 || hr > 110)) ||
      (spo2 != null && spo2 < 94) ||
      (temp != null && (temp >= 37.8 || temp < 36));

  if (warning) {
    return const _OverviewStatus(
      label: 'Một số chỉ số cần chú ý',
      icon: Icons.warning_amber_rounded,
      background: Color(0xFFFFFBEB),
      border: Color(0xFFFDE68A),
      iconBackground: Color(0xFFFEF3C7),
      iconColor: AppColors.warning,
      textColor: Color(0xFF92400E),
    );
  }

  return const _OverviewStatus(
    label: 'Tình trạng tổng quan ổn định',
    icon: Icons.check_circle_outline_rounded,
    background: Color(0xFFF0FDF4),
    border: Color(0xFFBBF7D0),
    iconBackground: Color(0xFFDCFCE7),
    iconColor: AppColors.success,
    textColor: Color(0xFF166534),
  );
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

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

StatusTone _metricTone(Metric metric, double? value) {
  if (value == null || !value.isFinite) return StatusTone.neutral;

  switch (metric) {
    case Metric.hr:
      if (value < 45 || value > 130) return StatusTone.danger;
      if (value < 50 || value > 110) return StatusTone.warning;
      return StatusTone.success;
    case Metric.spo2:
      if (value < 90) return StatusTone.danger;
      if (value < 94) return StatusTone.warning;
      return StatusTone.success;
    case Metric.temp:
      if (value >= 39 || value < 35) return StatusTone.danger;
      if (value >= 37.8 || value < 36) return StatusTone.warning;
      return StatusTone.success;
    case Metric.rr:
      if (value < 10 || value > 30) return StatusTone.danger;
      if (value < 12 || value > 24) return StatusTone.warning;
      return StatusTone.success;
    case Metric.leadOff:
      return value == 1 ? StatusTone.danger : StatusTone.success;
  }
}

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
