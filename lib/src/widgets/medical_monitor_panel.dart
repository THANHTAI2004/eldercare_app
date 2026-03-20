import 'dart:math' as math;

import 'package:flutter/material.dart';

class MedicalMonitorPanel extends StatelessWidget {
  const MedicalMonitorPanel({
    super.key,
    this.hr,
    this.spo2,
    this.temp,
    this.rr,
    this.hrWave,
    this.spo2Wave,
    this.tempWave,
    this.rrWave,
    this.brightness = Brightness.light,
  });

  final double? hr;
  final double? spo2;
  final double? temp;
  final double? rr;
  final List<double>? hrWave;
  final List<double>? spo2Wave;
  final List<double>? tempWave;
  final List<double>? rrWave;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final padding = isCompact ? 14.0 : 18.0;
        final gap = isCompact ? 10.0 : 12.0;
        final radius = isCompact ? 18.0 : 22.0;
        final panelBackground =
            isDark ? const Color(0xFF0E1116) : const Color(0xFFF6F8FB);
        final panelBorder = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06);
        final headerText = isDark ? Colors.white : const Color(0xFF0B1220);
        final secondaryText = isDark ? Colors.white70 : Colors.black54;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: panelBorder),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                offset: const Offset(0, 12),
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông số sức khỏe',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: headerText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mỗi chỉ số có một đồ thị riêng để theo dõi biến động.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondaryText,
                ),
              ),
              SizedBox(height: gap + 2),
              _MonitorRow(
                brightness: brightness,
                compact: isCompact,
                label: 'Nhịp tim',
                unit: 'bpm',
                value: hr,
                color: const Color(0xFF18B46B),
                icon: Icons.favorite_rounded,
                wave: hrWave,
              ),
              SizedBox(height: gap),
              _MonitorRow(
                brightness: brightness,
                compact: isCompact,
                label: 'SpO2',
                unit: '%',
                value: spo2,
                color: const Color(0xFF2F80ED),
                icon: Icons.water_drop_rounded,
                wave: spo2Wave,
              ),
              SizedBox(height: gap),
              _MonitorRow(
                brightness: brightness,
                compact: isCompact,
                label: 'Nhiệt độ',
                unit: '°C',
                value: temp,
                color: const Color(0xFFF2B705),
                icon: Icons.thermostat_rounded,
                wave: tempWave,
              ),
              SizedBox(height: gap),
              _MonitorRow(
                brightness: brightness,
                compact: isCompact,
                label: 'Nhịp thở',
                unit: 'rpm',
                value: rr,
                color: const Color(0xFF7B61FF),
                icon: Icons.air_rounded,
                wave: rrWave,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.brightness,
    required this.compact,
    required this.label,
    required this.unit,
    required this.value,
    required this.color,
    required this.icon,
    required this.wave,
  });

  final Brightness brightness;
  final bool compact;
  final String label;
  final String unit;
  final double? value;
  final Color color;
  final IconData icon;
  final List<double>? wave;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final hasValue = value != null && value!.isFinite;
    final chartPoints = _buildChartPoints(wave, hasValue: hasValue);
    final hasHistory = wave != null && wave!.isNotEmpty;
    final valueText = hasValue
        ? (unit == '°C' ? value!.toStringAsFixed(1) : value!.round().toString())
        : '--';
    final tileBackground = isDark ? const Color(0xFF10141B) : Colors.white;
    final tileBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final primaryText = isDark ? Colors.white : const Color(0xFF0B1220);
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: tileBackground,
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconPill(
                icon: icon,
                color: color,
                brightness: brightness,
                compact: compact,
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasHistory
                          ? 'Đồ thị riêng của chỉ số này'
                          : 'Chưa có dữ liệu lịch sử',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: hasHistory
                            ? color.withValues(alpha: 0.9)
                            : secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: TextStyle(
                      fontSize: compact ? 24 : 28,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: hasValue
                          ? primaryText
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: hasValue
                          ? color.withValues(alpha: 0.9)
                          : secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          SizedBox(
            height: compact ? 64 : 74,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
              child: CustomPaint(
                painter: _SparklinePainter(
                  points: chartPoints,
                  color: color,
                  brightness: brightness,
                  dim: !hasHistory,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.color,
    required this.brightness,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final Brightness brightness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;

    return Container(
      width: compact ? 40 : 44,
      height: compact ? 40 : 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: isDark ? 0.16 : 0.12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.22),
        ),
      ),
      child: Icon(
        icon,
        color: color.withValues(alpha: 0.95),
        size: compact ? 20 : 22,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.color,
    required this.brightness,
    required this.dim,
  });

  final List<double> points;
  final Color color;
  final Brightness brightness;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0B0E13) : const Color(0xFFF1F5FA);
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    _drawGrid(canvas, size, isDark);
    if (points.isEmpty) return;

    final path = Path();
    for (int index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? size.width / 2
          : (index / (points.length - 1)) * size.width;
      final y = (1.0 - points[index]) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final baseColor = dim ? (isDark ? Colors.white24 : Colors.black26) : color;

    final glowPaint = Paint()
      ..color = baseColor.withValues(alpha: dim ? 0.10 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = baseColor.withValues(alpha: dim ? 0.70 : 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    if (points.length == 1) {
      final pointPaint = Paint()
        ..color = baseColor.withValues(alpha: dim ? 0.7 : 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        3.5,
        pointPaint,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size, bool isDark) {
    final small = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(
        alpha: isDark ? 0.04 : 0.05,
      )
      ..strokeWidth = 1;
    final big = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(
        alpha: isDark ? 0.07 : 0.08,
      )
      ..strokeWidth = 1;

    const smallStep = 18.0;
    const bigEvery = 5;

    for (double x = 0; x <= size.width; x += smallStep) {
      final paint = ((x / smallStep).round() % bigEvery == 0) ? big : small;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += smallStep) {
      final paint = ((y / smallStep).round() % bigEvery == 0) ? big : small;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.brightness != brightness ||
        oldDelegate.dim != dim;
  }
}

List<double> _buildChartPoints(List<double>? rawValues, {required bool hasValue}) {
  if (rawValues == null || rawValues.isEmpty) {
    return _placeholderPoints(hasSignal: hasValue, length: 32);
  }

  final finiteValues = rawValues
      .where((value) => value.isFinite)
      .toList(growable: false);
  if (finiteValues.isEmpty) {
    return _placeholderPoints(hasSignal: hasValue, length: 32);
  }

  final sampled = _sampleValues(finiteValues, maxPoints: 40);
  if (sampled.length == 1) {
    return const [0.5];
  }

  double minValue = sampled.first;
  double maxValue = sampled.first;
  for (final value in sampled.skip(1)) {
    if (value < minValue) minValue = value;
    if (value > maxValue) maxValue = value;
  }

  final span = maxValue - minValue;
  if (span.abs() < 0.0001) {
    return List<double>.filled(sampled.length, 0.5, growable: false);
  }

  return sampled
      .map((value) => ((value - minValue) / span).clamp(0.0, 1.0).toDouble())
      .toList(growable: false);
}

List<double> _sampleValues(List<double> values, {required int maxPoints}) {
  if (values.length <= maxPoints) return values;

  return List<double>.generate(maxPoints, (index) {
    final sourceIndex =
        ((values.length - 1) * index / (maxPoints - 1)).round();
    return values[sourceIndex];
  }, growable: false);
}

List<double> _placeholderPoints({
  required bool hasSignal,
  required int length,
}) {
  return List<double>.generate(length, (index) {
    final t = index / math.max(1, length - 1);
    final amplitude = hasSignal ? 0.10 : 0.02;
    return (0.5 + amplitude * math.sin(t * math.pi * 4)).clamp(0.0, 1.0);
  }, growable: false);
}
