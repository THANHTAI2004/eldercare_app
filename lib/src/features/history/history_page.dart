import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/date_picker_button.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final current = context.read<DeviceProvider>().current;
      final realtime = context.read<RealtimeProvider>();
      final history = context.read<HistoryProvider>();
      await realtime.init(deviceId: current?.resolvedDeviceId);
      await history.bindScope(
        deviceId: current?.resolvedDeviceId ?? '',
        dayLocal: _dayLocal,
        load: true,
      );
    });
  }

  Future<void> _onPickDay(DateTime d) async {
    final dayLocal = DateTime(d.year, d.month, d.day);
    setState(() => _dayLocal = dayLocal);

    await context.read<HistoryProvider>().loadForDay(dayLocal);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final session = context.watch<SessionProvider>();
    final currentDevice = context.watch<DeviceProvider>().current;

    final dayPoints = history.metricPointsForSelectedDay(_metric);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lich su'),
        actions: [
          IconButton(
            tooltip: 'Lam moi ngay dang chon',
            onPressed: history.status.isLoading
                ? null
                : () => history.loadForDay(_dayLocal),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                DatePickerButton(value: _dayLocal, onChanged: _onPickDay),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricDropdown(
                    value: _metric,
                    onChanged: (m) => setState(() => _metric = m),
                  ),
                ),
              ],
            ),
            if (history.error != null && history.error!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _HistoryBanner(
                message: history.error!,
                isError:
                    !history.hasNoDataError && !history.isShowingCachedHistory,
              ),
            ] else if (!session.isAuthenticated) ...[
              const SizedBox(height: 12),
              const _HistoryBanner(
                message: 'Ban chua dang nhap. Vao muc Thiet bi de dang nhap.',
                isError: false,
              ),
            ] else if (currentDevice == null) ...[
              const SizedBox(height: 12),
              const _HistoryBanner(
                message: 'Chua co device dang theo doi. Hay chon device truoc.',
                isError: false,
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: history.status.isLoading && dayPoints.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : dayPoints.isEmpty
                  ? const _HistoryEmptyState()
                  : LineChartCard(
                      title: 'Theo gio trong ngay',
                      metric: _metric,
                      points: dayPoints,
                      showHourAxis: true,
                    ),
            ),
          ],
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
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = context.watch<HistoryProvider>();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          const Text(
            'Chua co du lieu lich su',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            history.hasNoDataError
                ? 'Device da duoc lien ket nhung chua co history tren server.'
                : 'Thu doi ngay khac hoac refresh lai sau khi thiet bi gui du lieu moi.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
