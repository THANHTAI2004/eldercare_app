import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({
    super.key,
    required this.metric,
    required this.points,
  });

  final Metric metric;
  final List<VitalPoint> points;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: points.length,
        separatorBuilder: (context, index) => const Divider(height: 16),
        itemBuilder: (context, i) {
          final p = points[i];
          final v = p.valueOf(metric);
          return ListTile(
            title: Text(
              v == null
                  ? '--'
                  : '${v.toStringAsFixed(metric == Metric.temp ? 1 : 0)} ${metric.unit}',
            ),
            subtitle: Text(
              DateFormat('HH:mm:ss dd/MM').format(p.time.toLocal()),
            ),
          );
        },
      ),
    );
  }
}
