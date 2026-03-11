import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
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
      final p = context.read<RealtimeProvider>();
      await p.init(userId: current?.id, deviceId: current?.deviceId);
      await p.loadHistoryForLocalDay(dayLocal: _dayLocal);
    });
  }

  Future<void> _onPickDay(DateTime d) async {
    final dayLocal = DateTime(d.year, d.month, d.day);
    setState(() => _dayLocal = dayLocal);

    await context.read<RealtimeProvider>().loadHistoryForLocalDay(
      dayLocal: dayLocal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RealtimeProvider>();

    final dayPoints = p.historyForLocalDay(_dayLocal).where((e) {
      final v = e.valueOf(_metric);
      return v != null && v.isFinite;
    }).toList()..sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lich su'),
        actions: [
          IconButton(
            tooltip: 'Lam moi ngay dang chon',
            onPressed: p.isLoadingHistory
                ? null
                : () => p.loadHistoryForLocalDay(dayLocal: _dayLocal),
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
            if (p.error != null && p.error!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _HistoryBanner(message: p.error!),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: p.isLoadingHistory && dayPoints.isEmpty
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
  const _HistoryBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onErrorContainer,
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
          const Text(
            'Thu doi ngay khac hoac refresh lai sau khi thiet bi gui du lieu moi.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
