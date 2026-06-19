import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/section_header.dart';

class HealthChartCard extends StatelessWidget {
  const HealthChartCard({
    super.key,
    required this.title,
    required this.metric,
    required this.points,
    this.subtitle,
    this.height = 220,
    this.actionLabel,
    this.onAction,
    this.emptyMessage,
  });

  final String title;
  final String? subtitle;
  final Metric metric;
  final List<VitalPoint> points;
  final double height;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var index = 0; index < points.length; index++) {
      final value = points[index].valueOf(metric);
      if (value == null || !value.isFinite) continue;
      spots.add(FlSpot(index.toDouble(), value));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (spots.isEmpty)
            SizedBox(
              height: height,
              child: Center(
                child: Text(
                  emptyMessage ?? 'Chưa có dữ liệu biểu đồ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  minY: _minY(spots),
                  maxY: _maxY(spots),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: _interval(spots),
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border,
                      dashArray: const [4, 4],
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toStringAsFixed(metric == Metric.temp ? 1 : 0),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _bottomInterval(spots.length),
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('HH:mm').format(points[index].time.toLocal()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) {
                        return spots
                            .map(
                              (spot) => LineTooltipItem(
                                '${spot.y.toStringAsFixed(metric == Metric.temp ? 1 : 0)} ${metric.unit}\n${DateFormat('HH:mm').format(points[spot.x.toInt()].time.toLocal())}',
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(growable: false);
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: _metricColor(metric),
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _metricColor(metric).withValues(alpha: 0.24),
                            _metricColor(metric).withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _minY(List<FlSpot> spots) {
    final min = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    return min - _padding(spots);
  }

  double _maxY(List<FlSpot> spots) {
    final max = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return max + _padding(spots);
  }

  double _padding(List<FlSpot> spots) {
    final min = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final max = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final span = max - min;
    return span == 0 ? 1 : span * 0.12;
  }

  double _interval(List<FlSpot> spots) {
    final min = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final max = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs();
    if (span <= 4) return 1;
    if (span <= 20) return 5;
    if (span <= 60) return 10;
    return 20;
  }

  double _bottomInterval(int count) {
    if (count <= 4) return 1;
    if (count <= 12) return 3;
    if (count <= 24) return 6;
    return (count / 4).ceilToDouble();
  }

  Color _metricColor(Metric metric) {
    switch (metric) {
      case Metric.hr:
        return const Color(0xFFE11D48);
      case Metric.spo2:
        return const Color(0xFF2563EB);
      case Metric.temp:
        return const Color(0xFF14B8A6);
      case Metric.rr:
        return const Color(0xFFF59E0B);
      case Metric.leadOff:
        return AppColors.danger;
    }
  }
}
