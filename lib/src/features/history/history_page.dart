import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/app_layout.dart';
import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/date_picker_button.dart';
import 'package:eldercare_app/src/widgets/ecg_waveform_card.dart';
import 'package:eldercare_app/src/widgets/line_chart_card.dart';
import 'package:eldercare_app/src/widgets/metric_dropdown.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _dayLocal = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  Metric _metric = Metric.hr;
  bool _didInit = false;

  bool get _showsEcgHistory => _metric == Metric.leadOff;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final current = context.read<DeviceProvider>().current;
      final realtime = context.read<RealtimeProvider>();
      final history = context.read<HistoryProvider>();
      final ecg = context.read<EcgProvider>();
      final deviceId = current?.resolvedDeviceId ?? '';

      ecg.bindScope(deviceId: deviceId);
      await realtime.init(deviceId: deviceId);
      await history.bindScope(
        deviceId: deviceId,
        dayLocal: _dayLocal,
        load: true,
      );
    });
  }

  Future<void> _onPickDay(DateTime day) async {
    final dayLocal = DateTime(day.year, day.month, day.day);
    setState(() => _dayLocal = dayLocal);

    await _loadSelectedHistoryForDay(dayLocal);
  }

  Future<void> _loadSelectedHistoryForDay(DateTime dayLocal) async {
    if (_showsEcgHistory) {
      await context.read<EcgProvider>().loadHistoryForDay(dayLocal);
      return;
    }

    await context.read<HistoryProvider>().loadForDay(dayLocal);
  }

  Future<void> _onMetricChanged(Metric metric) async {
    if (_metric == metric) return;

    setState(() => _metric = metric);

    if (metric != Metric.leadOff) return;

    final ecg = context.read<EcgProvider>();
    final sameDay =
        ecg.selectedHistoryDayLocal.year == _dayLocal.year &&
        ecg.selectedHistoryDayLocal.month == _dayLocal.month &&
        ecg.selectedHistoryDayLocal.day == _dayLocal.day;

    if (sameDay &&
        (ecg.historyReadings.isNotEmpty ||
            ecg.historyStatus == AsyncStatus.empty ||
            ecg.historyStatus == AsyncStatus.loading)) {
      return;
    }

    await ecg.loadHistoryForDay(_dayLocal);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final ecg = context.watch<EcgProvider>();
    final session = context.watch<SessionProvider>();
    final currentDevice = context.watch<DeviceProvider>().current;
    final layout = AppLayout.of(context);
    final isCompact = layout == AppLayoutSize.compact;
    final contentMaxWidth = AppLayout.maxContentWidth(context, override: 1100);
    final pagePadding = AppLayout.pagePadding(
      context,
      compact: 12,
      medium: 20,
      expanded: 24,
      bottom: 16,
    );

    final dayPoints = history.metricPointsForSelectedDay(_metric);
    final isLoadingSelected = _showsEcgHistory
        ? ecg.isLoadingHistory
        : history.status.isLoading;
    final selectedError = _showsEcgHistory ? ecg.historyError : history.error;
    final hasNoDataError = _showsEcgHistory
        ? ecg.hasNoHistoryDataError
        : history.hasNoDataError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử'),
        actions: [
          IconButton(
            tooltip: 'Làm mới ngày đang chọn',
            onPressed: isLoadingSelected
                ? null
                : () => _loadSelectedHistoryForDay(_dayLocal),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: Padding(
            padding: pagePadding,
            child: Column(
              children: [
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DatePickerButton(value: _dayLocal, onChanged: _onPickDay),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: MetricDropdown(
                          value: _metric,
                          onChanged: _onMetricChanged,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      DatePickerButton(value: _dayLocal, onChanged: _onPickDay),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricDropdown(
                          value: _metric,
                          onChanged: _onMetricChanged,
                        ),
                      ),
                    ],
                  ),
                if (selectedError != null &&
                    selectedError.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _HistoryBanner(
                    message: selectedError,
                    isError: !hasNoDataError,
                  ),
                ] else if (!session.isAuthenticated) ...[
                  const SizedBox(height: 12),
                  const _HistoryBanner(
                    message:
                        'Bạn chưa đăng nhập. Vào mục Thiết bị để đăng nhập.',
                    isError: false,
                  ),
                ] else if (currentDevice == null) ...[
                  const SizedBox(height: 12),
                  const _HistoryBanner(
                    message:
                        'Chưa có thiết bị đang theo dõi. Hãy chọn thiết bị trước.',
                    isError: false,
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child:
                      isLoadingSelected &&
                          ((_showsEcgHistory && ecg.historyReadings.isEmpty) ||
                              (!_showsEcgHistory && dayPoints.isEmpty))
                      ? const Center(child: CircularProgressIndicator())
                      : _showsEcgHistory
                      ? _EcgHistoryList(
                          readings: ecg.historyReadings,
                          hasNoDataError: ecg.hasNoHistoryDataError,
                        )
                      : dayPoints.isEmpty
                      ? _HistoryEmptyState(
                          hasNoDataError: history.hasNoDataError,
                        )
                      : LineChartCard(
                          title: 'Theo giờ trong ngày',
                          metric: _metric,
                          points: dayPoints,
                          showHourAxis: true,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryBanner extends StatelessWidget {
  const _HistoryBanner({required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isError ? scheme.onErrorContainer : scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({this.hasNoDataError = false});

  final bool hasNoDataError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          const Text(
            'Chưa có dữ liệu lịch sử',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasNoDataError
                ? 'Thiết bị đã được liên kết nhưng chưa có dữ liệu lịch sử trên máy chủ.'
                : 'Thử đổi ngày khác hoặc làm mới lại sau khi thiết bị gửi dữ liệu mới.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EcgHistoryList extends StatelessWidget {
  const _EcgHistoryList({required this.readings, required this.hasNoDataError});

  final List<EcgReading> readings;
  final bool hasNoDataError;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return _EcgHistoryEmptyState(hasNoDataError: hasNoDataError);
    }

    return ListView(children: [EcgHistoryWaveformCard(readings: readings)]);
  }
}

class _EcgHistoryEmptyState extends StatelessWidget {
  const _EcgHistoryEmptyState({this.hasNoDataError = false});

  final bool hasNoDataError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_outlined, size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          const Text(
            'Chưa có dữ liệu ECG',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasNoDataError
                ? 'Thiết bị đã được liên kết nhưng chưa có bản ghi ECG trên máy chủ.'
                : 'Thử đổi ngày khác hoặc làm mới lại sau khi thiết bị gửi thêm dữ liệu ECG.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
