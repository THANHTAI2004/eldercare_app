import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/device_selector.dart';
import 'package:eldercare_app/src/ui/components/ecg_waveform_card.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/health_chart_card.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';
import 'package:eldercare_app/src/ui/components/responsive_grid.dart';
import 'package:eldercare_app/src/ui/components/section_header.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';
import 'package:eldercare_app/src/ui/components/summary_stat_card.dart';

// ---------------------------------------------------------------------------
// Tab definitions
// ---------------------------------------------------------------------------

enum _HistoryTab { hr, spo2, temp, ecg }

extension _HistoryTabX on _HistoryTab {
  String get label {
    switch (this) {
      case _HistoryTab.hr:
        return 'Nhịp tim';
      case _HistoryTab.spo2:
        return 'SpO₂';
      case _HistoryTab.temp:
        return 'Nhiệt độ';
      case _HistoryTab.ecg:
        return 'ECG';
    }
  }

  IconData get icon {
    switch (this) {
      case _HistoryTab.hr:
        return Icons.favorite_rounded;
      case _HistoryTab.spo2:
        return Icons.bloodtype_outlined;
      case _HistoryTab.temp:
        return Icons.thermostat_rounded;
      case _HistoryTab.ecg:
        return Icons.monitor_heart_outlined;
    }
  }
}

// ---------------------------------------------------------------------------
// HistoryPage
// ---------------------------------------------------------------------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.initialMetric});

  final Metric? initialMetric;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = _HistoryTab.values; // hr, spo2, temp, ecg

  late TabController _tabController;
  late DateTime _fromDate;
  late DateTime _toDate;
  String? _dateRangeError;
  String? _lastScopeKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _toDate = DateTime(now.year, now.month, now.day);
    _fromDate = _toDate.subtract(const Duration(days: 7));

    final initialTab = _tabForMetric(widget.initialMetric);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _tabs.indexOf(initialTab),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── scope binding ──────────────────────────────────────────────────────────

  void _syncScope() {
    final device = context.read<DeviceProvider>().current;
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final nextKey =
        '${history.isAuthenticated}::${device?.resolvedDeviceId ?? ''}';
    if (_lastScopeKey == nextKey) return;
    _lastScopeKey = nextKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final deviceId = device?.resolvedDeviceId ?? '';
      await history.bindScope(
        deviceId: deviceId,
        dayLocal: _toDate,
        load: true,
      );
      ecg.bindScope(deviceId: deviceId);
      await ecg.loadHistoryForDay(_toDate);
    });
  }

  // ── device selection ───────────────────────────────────────────────────────

  Future<void> _selectDevice(String? deviceId) async {
    final id = deviceId?.trim() ?? '';
    if (id.isEmpty) return;
    final dp = context.read<DeviceProvider>();
    await dp.setCurrent(id);
    final current = dp.current;
    if (current == null || !mounted) return;
    final resolvedId = current.resolvedDeviceId;
    final historyProvider = context.read<HistoryProvider>();
    final ecgProvider = context.read<EcgProvider>();
    await historyProvider.bindScope(
      deviceId: resolvedId,
      dayLocal: _toDate,
      load: true,
    );
    ecgProvider.bindScope(deviceId: resolvedId);
    await ecgProvider.loadHistoryForDay(_toDate);
  }

  // ── date range ─────────────────────────────────────────────────────────────

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
      helpText: 'Chọn ngày bắt đầu',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDate = DateTime(picked.year, picked.month, picked.day);
      _dateRangeError = null;
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
      helpText: 'Chọn ngày kết thúc',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _toDate = DateTime(picked.year, picked.month, picked.day);
      _dateRangeError = null;
    });
  }

  void _applyFilter() {
    if (_fromDate.isAfter(_toDate)) {
      setState(
        () => _dateRangeError =
            'Ngày bắt đầu không được lớn hơn ngày kết thúc.',
      );
      return;
    }
    setState(() => _dateRangeError = null);
    _refresh();
  }

  Future<void> _refresh() async {
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    await history.loadForDay(_toDate);
    await ecg.loadHistoryForDay(_toDate);
  }

  // ── filtering ──────────────────────────────────────────────────────────────

  List<VitalPoint> _filterPoints(List<VitalPoint> points) {
    if (_fromDate.isAfter(_toDate)) return const [];
    final endOfTo = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
      999,
    );
    return points.where((p) {
      final local = p.time.toLocal();
      return !local.isBefore(_fromDate) && !local.isAfter(endOfTo);
    }).toList(growable: false)
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  List<EcgReading> _filterEcg(List<EcgReading> readings) {
    if (_fromDate.isAfter(_toDate)) return const [];
    final endOfTo = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
      999,
    );
    return readings.where((r) {
      final local = r.recordedAt.toLocal();
      return !local.isBefore(_fromDate) && !local.isAfter(endOfTo);
    }).toList(growable: false)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final history = context.watch<HistoryProvider>();
    final ecg = context.watch<EcgProvider>();
    final currentDevice = deviceProvider.current;
    _syncScope();

    final allPoints = _filterPoints(history.points);
    final ecgReadings = _filterEcg(ecg.historyReadings);
    final rangeLabel = _buildRangeLabel(_fromDate, _toDate);
    final canPop = Navigator.of(context).canPop();
    final isLoading = history.status.isLoading && history.points.isEmpty;

    return AppScaffold(
      title: 'Lịch sử sức khỏe',
      leading: canPop
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: history.status.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: currentDevice == null
          ? Column(
              children: [
                _buildHeader(
                  context,
                  deviceProvider: deviceProvider,
                  history: history,
                  currentDevice: currentDevice,
                  rangeLabel: rangeLabel,
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            )
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeader(
                          context,
                          deviceProvider: deviceProvider,
                          history: history,
                          currentDevice: currentDevice,
                          rangeLabel: rangeLabel,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      child: _buildTabBar(context),
                    ),
                  ),
                ];
              },
              body: isLoading
                  ? const LoadingState(message: 'Đang tải dữ liệu lịch sử...')
                  : history.status == AsyncStatus.error && history.error != null
                      ? _ErrorCard(message: history.error!, onRetry: _refresh)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // HR
                            _VitalTabContent(
                              metric: Metric.hr,
                              label: 'Nhịp tim',
                              allPoints: allPoints,
                              rangeLabel: rangeLabel,
                              onRefresh: _refresh,
                            ),
                            // SpO2
                            _VitalTabContent(
                              metric: Metric.spo2,
                              label: 'SpO₂',
                              allPoints: allPoints,
                              rangeLabel: rangeLabel,
                              onRefresh: _refresh,
                            ),
                            // Temp
                            _VitalTabContent(
                              metric: Metric.temp,
                              label: 'Nhiệt độ',
                              allPoints: allPoints,
                              rangeLabel: rangeLabel,
                              onRefresh: _refresh,
                            ),
                            // ECG
                            _EcgTabContent(
                              readings: ecgReadings,
                              isLoading: ecg.isLoadingHistory,
                              error: ecg.historyError,
                              rangeLabel: rangeLabel,
                              onRefresh: _refresh,
                            ),
                          ],
                        ),
            ),
    );
  }

  // ── header: device selector + date filter ─────────────────────────────────

  Widget _buildHeader(
    BuildContext context, {
    required DeviceProvider deviceProvider,
    required HistoryProvider history,
    required dynamic currentDevice,
    required String rangeLabel,
  }) {
    if (currentDevice == null) {
      return EmptyState(
        icon: Icons.watch_off_outlined,
        title: 'Chưa có thiết bị theo dõi',
        message:
            'Hãy chọn hoặc liên kết một thiết bị để xem lịch sử sức khỏe.',
        actionLabel: 'Mở màn thiết bị',
        onAction: () => Navigator.pop(context),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeviceSelector(
          devices: deviceProvider.devices,
          currentDeviceId: currentDevice.id as String?,
          onChanged: _selectDevice,
          isBusy: deviceProvider.isSyncing || history.status.isLoading,
        ),
        const SizedBox(height: AppSpacing.lg),
        _DateRangeFilterCard(
          fromDate: _fromDate,
          toDate: _toDate,
          errorText: _dateRangeError,
          onPickFrom: _pickFromDate,
          onPickTo: _pickToDate,
          onApply: _applyFilter,
        ),
      ],
    );
  }

  // ── tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
        tabs: _tabs.map((tab) {
          return Tab(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 16),
                const SizedBox(width: 6),
                Text(tab.label),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 82.0;

  @override
  double get maxExtent => 82.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      // We give it a background to cover the scrolling content beneath it.
      // AppColors.background (or scaffold gradient colors) ensures it looks seamless.
      color: AppColors.background,
      child: Column(
        children: [
          child,
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return true;
  }
}

// ---------------------------------------------------------------------------
// _VitalTabContent — one scrollable tab for hr / spo2 / temp
// ---------------------------------------------------------------------------

class _VitalTabContent extends StatefulWidget {
  const _VitalTabContent({
    required this.metric,
    required this.label,
    required this.allPoints,
    required this.rangeLabel,
    required this.onRefresh,
  });

  final Metric metric;
  final String label;
  final List<VitalPoint> allPoints;
  final String rangeLabel;
  final Future<void> Function() onRefresh;

  @override
  State<_VitalTabContent> createState() => _VitalTabContentState();
}

class _VitalTabContentState extends State<_VitalTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final metricPoints = widget.allPoints
        .where((p) {
          final v = p.valueOf(widget.metric);
          return v != null && v.isFinite;
        })
        .toList(growable: false);

    final stats = _computeStats(metricPoints, widget.metric);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ── Summary stats ──
          _MetricStatsSummary(
            label: widget.label,
            metric: widget.metric,
            stats: stats,
            pointCount: metricPoints.length,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Scrollable chart ──
          _ScrollableChartWrapper(
            pointCount: metricPoints.length,
            child: HealthChartCard(
              title: 'Biểu đồ ${widget.label}',
              subtitle: widget.rangeLabel,
              metric: widget.metric,
              points: metricPoints,
              height: 280,
              emptyMessage:
                  'Không có dữ liệu ${widget.label} trong khoảng thời gian đã chọn.',
            ),
          ),
          const SizedBox(height: AppSpacing.section),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EcgTabContent — scrollable tab for ECG history
// ---------------------------------------------------------------------------

class _EcgTabContent extends StatefulWidget {
  const _EcgTabContent({
    required this.readings,
    required this.isLoading,
    required this.rangeLabel,
    required this.onRefresh,
    this.error,
  });

  final List<EcgReading> readings;
  final bool isLoading;
  final String? error;
  final String rangeLabel;
  final Future<void> Function() onRefresh;

  @override
  State<_EcgTabContent> createState() => _EcgTabContentState();
}

class _EcgTabContentState extends State<_EcgTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (widget.isLoading)
            const LoadingState(message: 'Đang tải lịch sử ECG...')
          else if (widget.error != null && widget.error!.isNotEmpty)
            _ErrorCard(message: widget.error!, onRetry: null)
          else if (widget.readings.isEmpty)
            EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'Chưa có bản ghi ECG',
              message:
                  'Chưa có bản ghi ECG trong khoảng thời gian đã chọn.',
            )
          else ...[
            // ── ECG summary stats ──
            _EcgSummaryStats(readings: widget.readings),
            const SizedBox(height: AppSpacing.lg),

            // ── Latest waveform ──
            if (widget.readings.last.hasWaveform) ...[
              ECGWaveformCard(
                reading: widget.readings.last,
                title: 'ECG mới nhất',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Full list ──
            if (widget.readings.length > 1) ...[
              SectionHeader(
                title: 'Tất cả bản ghi ECG',
                subtitle:
                    '${widget.readings.length} bản ghi • ${widget.rangeLabel}',
              ),
              const SizedBox(height: AppSpacing.md),
              ...widget.readings.reversed.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _EcgListItem(reading: r),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.section),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DateRangeFilterCard
// ---------------------------------------------------------------------------

class _DateRangeFilterCard extends StatelessWidget {
  const _DateRangeFilterCard({
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApply,
    this.errorText,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApply;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 480;
              final fromPicker = _DatePickerField(
                label: 'Từ ngày',
                value: fmt.format(fromDate),
                onTap: onPickFrom,
              );
              final toPicker = _DatePickerField(
                label: 'Đến ngày',
                value: fmt.format(toDate),
                onTap: onPickTo,
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: fromPicker),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: toPicker),
                  ],
                );
              }
              return Column(
                children: [
                  fromPicker,
                  const SizedBox(height: AppSpacing.md),
                  toPicker,
                ],
              );
            },
          ),
          if (errorText != null && errorText!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Áp dụng bộ lọc'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(10),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MetricStatsSummary
// ---------------------------------------------------------------------------

class _MetricStatsSummary extends StatelessWidget {
  const _MetricStatsSummary({
    required this.label,
    required this.metric,
    required this.stats,
    required this.pointCount,
  });

  final String label;
  final Metric metric;
  final _MetricStats? stats;
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Thống kê $label',
          subtitle: pointCount == 0
              ? 'Chưa có dữ liệu trong khoảng đã chọn'
              : '$pointCount điểm dữ liệu',
        ),
        const SizedBox(height: AppSpacing.md),
        ResponsiveGrid(
          minItemWidth: 160,
          children: [
            SummaryStatCard(
              label: 'Cao nhất',
              value: stats == null ? '--' : _fmtValue(stats!.max, metric),
              icon: Icons.arrow_upward_rounded,
              tone: StatusTone.danger,
            ),
            SummaryStatCard(
              label: 'Thấp nhất',
              value: stats == null ? '--' : _fmtValue(stats!.min, metric),
              icon: Icons.arrow_downward_rounded,
              tone: StatusTone.info,
            ),
            SummaryStatCard(
              label: 'Trung bình',
              value: stats == null ? '--' : _fmtValue(stats!.average, metric),
              icon: Icons.show_chart_rounded,
              tone: StatusTone.success,
            ),
            SummaryStatCard(
              label: 'Số điểm',
              value: pointCount.toString(),
              icon: Icons.dataset_outlined,
              tone: StatusTone.neutral,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _EcgSummaryStats
// ---------------------------------------------------------------------------

class _EcgSummaryStats extends StatelessWidget {
  const _EcgSummaryStats({required this.readings});

  final List<EcgReading> readings;

  @override
  Widget build(BuildContext context) {
    final latest = readings.last;
    final fmt = DateFormat('HH:mm dd/MM');
    final leadOffCount = readings.where((r) => r.leadOff == true).length;
    final hrs = readings
        .map((r) => r.ecgHr)
        .whereType<int>()
        .toList(growable: false);
    final avgHr = hrs.isEmpty
        ? '--'
        : '${(hrs.reduce((a, b) => a + b) / hrs.length).round()} bpm';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Thống kê ECG',
          subtitle: '${readings.length} bản ghi trong khoảng đã chọn',
        ),
        const SizedBox(height: AppSpacing.md),
        ResponsiveGrid(
          minItemWidth: 160,
          children: [
            SummaryStatCard(
              label: 'Số bản ghi',
              value: readings.length.toString(),
              icon: Icons.monitor_heart_outlined,
              tone: StatusTone.info,
            ),
            SummaryStatCard(
              label: 'Bản ghi mới nhất',
              value: fmt.format(latest.recordedAt.toLocal()),
              icon: Icons.schedule_rounded,
              tone: StatusTone.neutral,
            ),
            SummaryStatCard(
              label: 'ECG HR trung bình',
              value: avgHr,
              icon: Icons.favorite_border_rounded,
              tone: StatusTone.success,
            ),
            if (leadOffCount > 0)
              SummaryStatCard(
                label: 'Lead off',
                value: '$leadOffCount bản ghi',
                icon: Icons.warning_amber_rounded,
                tone: StatusTone.warning,
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ScrollableChartWrapper
// ---------------------------------------------------------------------------

class _ScrollableChartWrapper extends StatefulWidget {
  const _ScrollableChartWrapper({
    required this.pointCount,
    required this.child,
  });

  final int pointCount;
  final Widget child;

  @override
  State<_ScrollableChartWrapper> createState() =>
      _ScrollableChartWrapperState();
}

class _ScrollableChartWrapperState extends State<_ScrollableChartWrapper> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final chartWidth = widget.pointCount > 0
            ? (widget.pointCount * 40.0).clamp(screenWidth, double.infinity)
            : screenWidth;

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: chartWidth, child: widget.child),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _EcgListItem
// ---------------------------------------------------------------------------

class _EcgListItem extends StatelessWidget {
  const _EcgListItem({required this.reading});

  final EcgReading reading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('HH:mm, dd/MM/yyyy');
    final quality = (reading.quality ?? '').trim();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.monitor_heart_outlined,
              size: 20,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(reading.recordedAt.toLocal()),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (reading.ecgHr != null)
                      Text(
                        '${reading.ecgHr} bpm',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (quality.isNotEmpty)
                      StatusBadge(
                        label: quality,
                        tone: quality.toLowerCase() == 'good'
                            ? StatusTone.success
                            : StatusTone.info,
                      ),
                    if (reading.leadOff == true)
                      const StatusBadge(
                        label: 'Lead off',
                        tone: StatusTone.warning,
                        icon: Icons.warning_amber_rounded,
                      ),
                    Text(
                      '${reading.waveform.length} mẫu',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorCard
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.danger.withValues(alpha: 0.3),
      backgroundColor: AppColors.danger.withValues(alpha: 0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lỗi tải dữ liệu',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

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

_MetricStats? _computeStats(List<VitalPoint> points, Metric metric) {
  final values = points
      .map((p) => p.valueOf(metric))
      .whereType<double>()
      .where((v) => v.isFinite)
      .toList(growable: false);
  if (values.isEmpty) return null;
  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final avg = values.reduce((a, b) => a + b) / values.length;
  return _MetricStats(min: min, max: max, average: avg);
}

String _fmtValue(double value, Metric metric) {
  if (metric == Metric.temp) return '${value.toStringAsFixed(1)} °C';
  return '${value.round()} ${metric.unit}';
}

String _buildRangeLabel(DateTime from, DateTime to) {
  final fmt = DateFormat('dd/MM/yyyy');
  return '${fmt.format(from)} – ${fmt.format(to)}';
}

_HistoryTab _tabForMetric(Metric? metric) {
  switch (metric) {
    case Metric.hr:
      return _HistoryTab.hr;
    case Metric.spo2:
      return _HistoryTab.spo2;
    case Metric.temp:
      return _HistoryTab.temp;
    default:
      return _HistoryTab.hr;
  }
}
