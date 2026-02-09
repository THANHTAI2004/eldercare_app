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
    // Lọc data hợp lệ
    final data = <_ChartPoint>[];
    for (final p in points) {
      final raw = p.valueOf(metric);
      if (raw == null) continue;
      final v = (raw as num).toDouble();
      if (v.isNaN || v.isInfinite) continue;
      data.add(_ChartPoint(time: p.time, value: v));
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // ❗ Giữ chiều cao cố định ~ như bản cũ
            SizedBox(
              height: 220,
              child: _InteractiveChart(data: data),
            ),
            const SizedBox(height: 8),
            _TimeAxis(
              data: data,
              showHourAxis: showHourAxis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPoint {
  _ChartPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

/// Chart tương tác: di chuột / chạm để hiện cột dọc + tooltip
class _InteractiveChart extends StatefulWidget {
  const _InteractiveChart({required this.data});

  final List<_ChartPoint> data;

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  _ChartPoint? _selected;
  double? _selectedX; // tọa độ X trên canvas

  void _updateSelected(Offset localPos, Size size) {
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
    double bestDist = double.infinity;
    double? bestX;

    for (final p in data) {
      final t = p.time.millisecondsSinceEpoch.toDouble();
      final x = dx == 0 ? size.width / 2 : (t - minTime) * scaleX;
      final d = (x - localPos.dx).abs();
      if (d < bestDist) {
        bestDist = d;
        nearest = p;
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
            gridColor: scheme.outline.withOpacity(0.3),
            highlightX: _selectedX,
            highlightPoint: _selected,
          ),
        );

        // Tooltip khi có điểm được chọn
        if (_selected != null && _selectedX != null) {
          final valText = _selected!.value.toStringAsFixed(1);
          final timeText =
          DateFormat('HH:mm').format(_selected!.time.toLocal());

          const tooltipWidth = 90.0;
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$valText • $timeText',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
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
            onTapDown: (details) =>
                _updateSelected(details.localPosition, size),
            onPanDown: (details) =>
                _updateSelected(details.localPosition, size),
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
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // 1) Vẽ grid
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const rows = 4;
    const cols = 6;
    for (int i = 1; i < rows; i++) {
      final y = h * i / rows;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (int j = 1; j < cols; j++) {
      final x = w * j / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    if (data.isEmpty) return;

    // 2) Min/max time & value
    final minTime = data.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = data.last.time.millisecondsSinceEpoch.toDouble();

    double minVal = data.first.value;
    double maxVal = data.first.value;
    for (final p in data.skip(1)) {
      if (p.value < minVal) minVal = p.value;
      if (p.value > maxVal) maxVal = p.value;
    }

    double plotMin = minVal;
    double plotMax = maxVal;
    final dyRaw = (plotMax - plotMin).abs();
    final paddingY = dyRaw == 0 ? 1.0 : dyRaw * 0.1;
    plotMin -= paddingY;
    plotMax += paddingY;

    final dx = (maxTime - minTime).abs();
    final dy = (plotMax - plotMin).abs();

    final scaleX = dx == 0 ? 0.0 : w / dx;
    final scaleY = dy == 0 ? 0.0 : h / dy;

    // 3) Chỉ 1 điểm → vẽ chấm
    if (data.length == 1) {
      final p = data.first;
      final t = p.time.millisecondsSinceEpoch.toDouble();

      final x = dx == 0 ? w / 2 : (t - minTime) * scaleX;
      final y = dy == 0 ? h / 2 : h - (p.value - plotMin) * scaleY;

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      return;
    }

    // 4) Nhiều điểm → vẽ path
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final p = data[i];
      final t = p.time.millisecondsSinceEpoch.toDouble();

      final x = dx == 0 ? w / 2 : (t - minTime) * scaleX;
      final y = dy == 0 ? h / 2 : h - (p.value - plotMin) * scaleY;

      if (i == 0) {
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

    // 5) Cột dọc + chấm highlight
    if (highlightX != null && highlightPoint != null) {
      final value = highlightPoint!.value;
      final hvY = dy == 0
          ? h / 2
          : h - (value - plotMin) * scaleY;

      final crossPaint = Paint()
        ..color = lineColor.withOpacity(0.7)
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(highlightX!, 0),
        Offset(highlightX!, h),
        crossPaint,
      );

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(highlightX!, hvY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) {
    return old.data != data ||
        old.lineColor != lineColor ||
        old.gridColor != gridColor ||
        old.highlightX != highlightX ||
        old.highlightPoint != highlightPoint;
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

    final format =
    showHourAxis ? DateFormat('HH:mm') : DateFormat('dd/MM');

    final labels = <String>[];
    // 4 mốc: đầu – 1/3 – 2/3 – cuối
    for (int i = 0; i < 4; i++) {
      final t = minTime.millisecondsSinceEpoch +
          ((maxTime.millisecondsSinceEpoch -
              minTime.millisecondsSinceEpoch) *
              i /
              3)
              .round();
      labels.add(
        format.format(
          DateTime.fromMillisecondsSinceEpoch(t).toLocal(),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (t) => Text(
          t,
          style: const TextStyle(fontSize: 10),
        ),
      )
          .toList(),
    );
  }
}
