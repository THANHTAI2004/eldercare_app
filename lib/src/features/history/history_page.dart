import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/device_selector.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/health_chart_card.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';
import 'package:eldercare_app/src/ui/components/section_header.dart';

enum _HistoryRange { today, sevenDays, thirtyDays }
enum _HistoryTab { overview, hr, spo2, temp, rr }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.initialMetric});

  final Metric? initialMetric;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  _HistoryRange _range = _HistoryRange.today;
  late _HistoryTab _selectedTab = _tabForMetric(widget.initialMetric);
  String? _lastScopeKey;

  void _syncScope() {
    final device = context.read<DeviceProvider>().current;
    final history = context.read<HistoryProvider>();
    final nextScopeKey = '${history.isAuthenticated}::${device?.resolvedDeviceId ?? ''}';
    if (_lastScopeKey == nextScopeKey) return;
    _lastScopeKey = nextScopeKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await history.bindScope(
        deviceId: device?.resolvedDeviceId ?? '',
        dayLocal: _todayLocal(),
        load: true,
      );
    });
  }

  Future<void> _selectDevice(String? deviceId) async {
    final selectedId = deviceId?.trim() ?? '';
    if (selectedId.isEmpty) return;
    final deviceProvider = context.read<DeviceProvider>();
    await deviceProvider.setCurrent(selectedId);
    final current = deviceProvider.current;
    if (current == null || !mounted) return;
    await context.read<HistoryProvider>().bindScope(
      deviceId: current.resolvedDeviceId,
      dayLocal: _todayLocal(),
      load: true,
    );
  }

  Future<void> _refresh() {
    return context.read<HistoryProvider>().loadForDay(_todayLocal());
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final history = context.watch<HistoryProvider>();
    final currentDevice = deviceProvider.current;
    _syncScope();

    final filteredPoints = _filterByRange(history.points, _range);
    final chartMetric = _selectedMetricForTab(_selectedTab);
    final metricPoints = filteredPoints
        .where((point) => point.valueOf(chartMetric) != null)
        .toList(growable: false)
      ..sort((a, b) => a.time.compareTo(b.time));

    final stats = _stats(metricPoints, chartMetric);
    final canPop = Navigator.of(context).canPop();

    return AppScaffold(
      title: 'Lịch sử sức khỏe',
      subtitle: 'Theo dõi xu hướng chỉ số sức khỏe theo thời gian.',
      leading: canPop
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      actions: [
        IconButton(
          onPressed: history.status.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (currentDevice != null)
              DeviceSelector(
                devices: deviceProvider.devices,
                currentDeviceId: currentDevice.id,
                onChanged: _selectDevice,
                isBusy: deviceProvider.isSyncing || history.status.isLoading,
              )
            else
              EmptyState(
                icon: Icons.watch_off_outlined,
                title: 'Chưa có thiết bị theo dõi',
                message:
                    'Hãy chọn hoặc liên kết một thiết bị để xem lịch sử sức khỏe.',
                actionLabel: 'Mở màn thiết bị',
                onAction: () => Navigator.pop(context),
              ),
            const SizedBox(height: AppSpacing.xl),
            _RangeSelector(
              selectedRange: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
            const SizedBox(height: AppSpacing.lg),
            _TabSelector(
              selectedTab: _selectedTab,
              onChanged: (tab) => setState(() => _selectedTab = tab),
            ),
            const SizedBox(height: AppSpacing.section),
            if (history.status.isLoading && history.points.isEmpty)
              const LoadingState(message: 'Đang tải dữ liệu lịch sử...')
            else if (filteredPoints.isEmpty)
              const EmptyState(
                icon: Icons.query_stats_outlined,
                title: 'Chưa có điểm dữ liệu',
                message:
                    'Thử làm mới lại sau khi thiết bị gửi thêm dữ liệu sức khỏe.',
              )
            else ...[
              if (_selectedTab == _HistoryTab.overview) ...[
                _OverviewMetrics(points: filteredPoints),
                const SizedBox(height: AppSpacing.section),
              ],
              HealthChartCard(
                title: _selectedTab == _HistoryTab.overview
                    ? 'Biểu đồ nhịp tim'
                    : 'Biểu đồ ${chartMetric.label.toLowerCase()}',
                subtitle: _rangeLabel(_range),
                metric: chartMetric,
                points: metricPoints,
                height: 260,
              ),
              const SizedBox(height: AppSpacing.section),
              _StatsRow(stats: stats, metric: chartMetric),
              const SizedBox(height: AppSpacing.section),
              _QuickInsightCard(
                metric: chartMetric,
                stats: stats,
                range: _range,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selectedRange,
    required this.onChanged,
  });

  final _HistoryRange selectedRange;
  final ValueChanged<_HistoryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SegmentedButton<_HistoryRange>(
        segments: const [
          ButtonSegment(value: _HistoryRange.today, label: Text('Hôm nay')),
          ButtonSegment(value: _HistoryRange.sevenDays, label: Text('7 ngày')),
          ButtonSegment(value: _HistoryRange.thirtyDays, label: Text('30 ngày')),
        ],
        selected: <_HistoryRange>{selectedRange},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.selectedTab,
    required this.onChanged,
  });

  final _HistoryTab selectedTab;
  final ValueChanged<_HistoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SegmentedButton<_HistoryTab>(
        segments: const [
          ButtonSegment(value: _HistoryTab.overview, label: Text('Tổng quan')),
          ButtonSegment(value: _HistoryTab.hr, label: Text('Nhịp tim')),
          ButtonSegment(value: _HistoryTab.spo2, label: Text('SpO2')),
          ButtonSegment(value: _HistoryTab.temp, label: Text('Nhiệt độ')),
          ButtonSegment(value: _HistoryTab.rr, label: Text('Nhịp thở')),
        ],
        selected: <_HistoryTab>{selectedTab},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({required this.points});

  final List<VitalPoint> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Tổng quan chỉ số',
          subtitle: 'Giá trị trung bình theo khoảng thời gian đã chọn.',
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.lg,
          crossAxisSpacing: AppSpacing.lg,
          childAspectRatio: 1.5,
          children: [
            _MiniMetricCard(
              title: 'Nhịp tim',
              value: _average(points, Metric.hr),
              unit: 'bpm',
              color: const Color(0xFFE11D48),
            ),
            _MiniMetricCard(
              title: 'SpO2',
              value: _average(points, Metric.spo2),
              unit: '%',
              color: AppColors.primary,
            ),
            _MiniMetricCard(
              title: 'Nhiệt độ',
              value: _average(points, Metric.temp, decimal: true),
              unit: '°C',
              color: AppColors.secondary,
            ),
            _MiniMetricCard(
              title: 'Nhịp thở',
              value: _average(points, Metric.rr),
              unit: '/phút',
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String title;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.metric});

  final _MetricStats? stats;
  final Metric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Thống kê nhanh',
          subtitle: 'Giá trị cao nhất, thấp nhất và trung bình.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Cao nhất',
                value: stats == null ? '--' : _formatValue(stats!.max, metric),
                accentColor: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _StatTile(
                label: 'Thấp nhất',
                value: stats == null ? '--' : _formatValue(stats!.min, metric),
                accentColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _StatTile(
                label: 'Trung bình',
                value: stats == null ? '--' : _formatValue(stats!.average, metric),
                accentColor: AppColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickInsightCard extends StatelessWidget {
  const _QuickInsightCard({
    required this.metric,
    required this.stats,
    required this.range,
  });

  final Metric metric;
  final _MetricStats? stats;
  final _HistoryRange range;

  @override
  Widget build(BuildContext context) {
    final text = _insightText(metric, stats, range);
    return AppCard(
      backgroundColor: const Color(0xFFF0FDF4),
      borderColor: const Color(0xFFBBF7D0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFDCFCE7),
            child: Icon(Icons.lightbulb_outline_rounded, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nhận xét nhanh', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricStats {
  const _MetricStats({
    required this.min,
    required this.max,
    required this.average,
  });

  final double min;
  final double max;
  final double average;
}

_HistoryTab _tabForMetric(Metric? metric) {
  switch (metric) {
    case Metric.hr:
      return _HistoryTab.hr;
    case Metric.spo2:
      return _HistoryTab.spo2;
    case Metric.temp:
      return _HistoryTab.temp;
    case Metric.rr:
      return _HistoryTab.rr;
    case Metric.leadOff:
    case null:
      return _HistoryTab.overview;
  }
}

Metric _selectedMetricForTab(_HistoryTab tab) {
  switch (tab) {
    case _HistoryTab.overview:
      return Metric.hr;
    case _HistoryTab.hr:
      return Metric.hr;
    case _HistoryTab.spo2:
      return Metric.spo2;
    case _HistoryTab.temp:
      return Metric.temp;
    case _HistoryTab.rr:
      return Metric.rr;
  }
}

List<VitalPoint> _filterByRange(List<VitalPoint> points, _HistoryRange range) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);

  final filtered = points.where((point) {
    final localTime = point.time.toLocal();
    switch (range) {
      case _HistoryRange.today:
        return localTime.year == startOfToday.year &&
            localTime.month == startOfToday.month &&
            localTime.day == startOfToday.day;
      case _HistoryRange.sevenDays:
        return localTime.isAfter(now.subtract(const Duration(days: 7)));
      case _HistoryRange.thirtyDays:
        return localTime.isAfter(now.subtract(const Duration(days: 30)));
    }
  }).toList(growable: false);

  filtered.sort((a, b) => a.time.compareTo(b.time));
  return filtered;
}

_MetricStats? _stats(List<VitalPoint> points, Metric metric) {
  final values = points
      .map((point) => point.valueOf(metric))
      .whereType<double>()
      .where((value) => value.isFinite)
      .toList(growable: false);
  if (values.isEmpty) return null;

  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final average = values.reduce((a, b) => a + b) / values.length;
  return _MetricStats(min: min, max: max, average: average);
}

String _average(List<VitalPoint> points, Metric metric, {bool decimal = false}) {
  final stats = _stats(points, metric);
  if (stats == null) return '--';
  return decimal
      ? stats.average.toStringAsFixed(1)
      : stats.average.round().toString();
}

String _formatValue(double value, Metric metric) {
  if (metric == Metric.temp) {
    return '${value.toStringAsFixed(1)} °C';
  }
  return '${value.round()} ${metric == Metric.rr ? '/phút' : metric.unit}';
}

String _rangeLabel(_HistoryRange range) {
  switch (range) {
    case _HistoryRange.today:
      return 'Khoảng thời gian: Hôm nay';
    case _HistoryRange.sevenDays:
      return 'Khoảng thời gian: 7 ngày gần nhất';
    case _HistoryRange.thirtyDays:
      return 'Khoảng thời gian: 30 ngày gần nhất';
  }
}

String _insightText(Metric metric, _MetricStats? stats, _HistoryRange range) {
  if (stats == null) {
    return 'Chưa đủ dữ liệu để đưa ra nhận xét cho khoảng thời gian đã chọn.';
  }

  final rangeText = switch (range) {
    _HistoryRange.today => 'trong hôm nay',
    _HistoryRange.sevenDays => 'trong 7 ngày gần đây',
    _HistoryRange.thirtyDays => 'trong 30 ngày gần đây',
  };

  switch (metric) {
    case Metric.hr:
      return 'Nhịp tim dao động từ ${stats.min.round()} đến ${stats.max.round()} bpm $rangeText, trung bình ${stats.average.round()} bpm.';
    case Metric.spo2:
      return 'SpO2 trung bình ${stats.average.round()}%, thấp nhất ${stats.min.round()}% $rangeText.';
    case Metric.temp:
      return 'Nhiệt độ cơ thể dao động quanh ${stats.average.toStringAsFixed(1)} °C $rangeText.';
    case Metric.rr:
      return 'Nhịp thở ghi nhận trung bình ${stats.average.round()} lần/phút $rangeText.';
    case Metric.leadOff:
      return 'Lead off không được sử dụng trong màn lịch sử tổng quan.';
  }
}

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
