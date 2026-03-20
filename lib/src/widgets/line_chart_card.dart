import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.metric,
    required this.points,
    this.showHourAxis = false,
  });

  final String title;
  final Metric metric;
  final List<VitalPoint> points;
  final bool showHourAxis;

  @override
  Widget build(BuildContext context) {
    final data = <_ChartPoint>[];
    for (final point in points) {
      final raw = point.valueOf(metric);
      if (raw == null) continue;

      final value = (raw as num).toDouble();
      if (value.isNaN || value.isInfinite) continue;
      data.add(_ChartPoint(time: point.time, value: value));
    }

    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text('Không có dữ liệu ${metric.label}'),
          ),
        ),
      );
    }

    data.sort((a, b) => a.time.compareTo(b.time));

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth >= 1000
            ? 320.0
            : constraints.maxWidth >= 700
            ? 260.0
            : 220.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: chartHeight,
                  child: _InteractiveChart(data: data),
                ),
                const SizedBox(height: 8),
                _TimeAxis(data: data, showHourAxis: showHourAxis),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChartPoint {
  _ChartPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class _InteractiveChart extends StatefulWidget {
  const _InteractiveChart({required this.data});

  final List<_ChartPoint> data;

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  _ChartPoint? _selected;
  double? _selectedX;

  void _updateSelected(Offset localPosition, Size size) {
    final data = widget.data;
    if (data.isEmpty) {
      setState(() {
        _selected = null;
        _selectedX = null;
      });
      return;
    }

    final minTime = data.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = data.last.time.millisecondsSinceEpoch.toDouble();
    final dx = (maxTime - minTime).abs();
    final scaleX = dx == 0 ? 0.0 : size.width / dx;

    _ChartPoint? nearest;
    double bestDistance = double.infinity;
    double? bestX;

    for (final point in data) {
      final time = point.time.millisecondsSinceEpoch.toDouble();
      final x = dx == 0 ? size.width / 2 : (time - minTime) * scaleX;
      final distance = (x - localPosition.dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = point;
        bestX = x;
      }
    }

    setState(() {
      _selected = nearest;
      _selectedX = bestX;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        Widget chart = CustomPaint(
          size: size,
          painter: _ChartPainter(
            data: widget.data,
            lineColor: scheme.primary,
            gridColor: scheme.outline.withValues(alpha: 0.3),
            highlightX: _selectedX,
            highlightPoint: _selected,
          ),
        );

        if (_selected != null && _selectedX != null) {
          final valueText = _selected!.value.toStringAsFixed(1);
          final timeText = DateFormat('HH:mm').format(_selected!.time.toLocal());

          const tooltipWidth = 96.0;
          double left = _selectedX! - tooltipWidth / 2;
          if (left < 0) left = 0;
          if (left > size.width - tooltipWidth) {
            left = size.width - tooltipWidth;
          }

          chart = Stack(
            children: [
              Positioned.fill(child: chart),
              Positioned(
                left: left,
                top: 8,
                child: Container(
                  width: tooltipWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$valueText - $timeText',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          );
        }

        return MouseRegion(
          onHover: (event) => _updateSelected(event.localPosition, size),
          onExit: (_) {
            setState(() {
              _selected = null;
              _selectedX = null;
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _updateSelected(details.localPosition, size),
            onPanDown: (details) => _updateSelected(details.localPosition, size),
            onPanUpdate: (details) =>
                _updateSelected(details.localPosition, size),
            child: chart,
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    this.highlightX,
    this.highlightPoint,
  });

  final List<_ChartPoint> data;
  final Color lineColor;
  final Color gridColor;
  final double? highlightX;
  final _ChartPoint? highlightPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const rows = 4;
    const cols = 6;
    for (int row = 1; row < rows; row++) {
      final y = height * row / rows;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }
    for (int col = 1; col < cols; col++) {
      final x = width * col / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }

    if (data.isEmpty) return;

    final minTime = data.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = data.last.time.millisecondsSinceEpoch.toDouble();

    double minValue = data.first.value;
    double maxValue = data.first.value;
    for (final point in data.skip(1)) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
    }

    double plotMin = minValue;
    double plotMax = maxValue;
    final dyRaw = (plotMax - plotMin).abs();
    final paddingY = dyRaw == 0 ? 1.0 : dyRaw * 0.1;
    plotMin -= paddingY;
    plotMax += paddingY;

    final dx = (maxTime - minTime).abs();
    final dy = (plotMax - plotMin).abs();
    final scaleX = dx == 0 ? 0.0 : width / dx;
    final scaleY = dy == 0 ? 0.0 : height / dy;

    if (data.length == 1) {
      final point = data.first;
      final time = point.time.millisecondsSinceEpoch.toDouble();
      final x = dx == 0 ? width / 2 : (time - minTime) * scaleX;
      final y =
          dy == 0 ? height / 2 : height - (point.value - plotMin) * scaleY;

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      return;
    }

    final path = Path();
    for (int index = 0; index < data.length; index++) {
      final point = data[index];
      final time = point.time.millisecondsSinceEpoch.toDouble();
      final x = dx == 0 ? width / 2 : (time - minTime) * scaleX;
      final y =
          dy == 0 ? height / 2 : height - (point.value - plotMin) * scaleY;

      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    if (highlightX != null && highlightPoint != null) {
      final value = highlightPoint!.value;
      final highlightY =
          dy == 0 ? height / 2 : height - (value - plotMin) * scaleY;

      final crossPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(highlightX!, 0),
        Offset(highlightX!, height),
        crossPaint,
      );

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(highlightX!, highlightY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.highlightX != highlightX ||
        oldDelegate.highlightPoint != highlightPoint;
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.data,
    required this.showHourAxis,
  });

  final List<_ChartPoint> data;
  final bool showHourAxis;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final minTime = data.first.time;
    final maxTime = data.last.time;
    final format = showHourAxis ? DateFormat('HH:mm') : DateFormat('dd/MM');

    final labels = <String>[];
    for (int index = 0; index < 4; index++) {
      final time = minTime.millisecondsSinceEpoch +
          ((maxTime.millisecondsSinceEpoch - minTime.millisecondsSinceEpoch) *
                  index /
                  3)
              .round();
      labels.add(
        format.format(DateTime.fromMillisecondsSinceEpoch(time).toLocal()),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Text(
              label,
              style: const TextStyle(fontSize: 10),
            ),
          )
          .toList(growable: false),
    );
  }
}
