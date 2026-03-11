import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VitalType { hr, spo2, temp, rr }

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
    this.brightness = Brightness.light, // ✅ mặc định nền trắng
  });

  final double? hr; // bpm
  final double? spo2; // %
  final double? temp; // °C
  final double? rr; // rpm

  /// Nếu bạn có waveform thật thì truyền vào (0..1).
  final List<double>? hrWave;
  final List<double>? spo2Wave;
  final List<double>? tempWave;
  final List<double>? rrWave;

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    final isDark = brightness == Brightness.dark;

    final panelBg = isDark ? const Color(0xFF0E1116) : const Color(0xFFF6F8FB);
    final panelBorder =
    isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: panelBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 12),
            color: (isDark ? Colors.black : Colors.black)
                .withValues(alpha: isDark ? 0.25 : 0.08),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MonitorTile(
                    brightness: brightness,
                    type: VitalType.hr,
                    label: 'HR',
                    unit: 'bpm',
                    value: hr,
                    color: const Color(0xFF18B46B),
                    icon: Icons.favorite_rounded,
                    wave: hrWave,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _MonitorTile(
                    brightness: brightness,
                    type: VitalType.spo2,
                    label: 'SpO₂',
                    unit: '%',
                    value: spo2,
                    color: const Color(0xFF2F80ED),
                    icon: Icons.water_drop_rounded,
                    wave: spo2Wave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MonitorTile(
                    brightness: brightness,
                    type: VitalType.temp,
                    label: 'Temp',
                    unit: '°C',
                    value: temp,
                    color: const Color(0xFFF2B705),
                    icon: Icons.thermostat_rounded,
                    wave: tempWave,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _MonitorTile(
                    brightness: brightness,
                    type: VitalType.rr,
                    label: 'RR',
                    unit: 'rpm',
                    value: rr,
                    color: const Color(0xFF7B61FF),
                    icon: Icons.air_rounded,
                    wave: rrWave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitorTile extends StatelessWidget {
  const _MonitorTile({
    required this.brightness,
    required this.type,
    required this.label,
    required this.unit,
    required this.value,
    required this.color,
    required this.icon,
    required this.wave,
  });

  final Brightness brightness;
  final VitalType type;
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
    final valueText = hasValue
        ? (type == VitalType.temp
        ? value!.toStringAsFixed(1)
        : value!.round().toString())
        : '--';

    final points = (wave != null && wave!.length >= 8)
        ? _clamp01(wave!)
        : _demoWave(type, hasSignal: hasValue, n: 220);

    final tileBg = isDark ? const Color(0xFF10141B) : Colors.white;
    final tileBorder =
    isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

    final primaryText = isDark ? Colors.white : const Color(0xFF0B1220);
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tileBorder),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.06),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _IconPill(icon: icon, color: color, brightness: brightness),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color.withValues(alpha: 0.95),
                ),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: hasValue
                      ? color
                      : (isDark ? Colors.white24 : Colors.black26),
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),

          const SizedBox(height: 10),

          // Big number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 44,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: hasValue
                      ? primaryText
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: hasValue ? color.withValues(alpha: 0.9) : secondaryText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Waveform area + ✅ badge "Chưa có dữ liệu" rõ ràng
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _WaveformPainter(
                      points: points,
                      color: color,
                      dim: !hasValue,
                      brightness: brightness,
                    ),
                    child: const SizedBox.expand(),
                  ),

                  // ✅ Badge nổi rõ (không chìm, không bị line che)
                  if (!hasValue)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                          ],
                        ),
                        child: Text(
                          'Chưa có dữ liệu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
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
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.color,
    required this.brightness,
  });

  final IconData icon;
  final Color color;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: isDark ? 0.16 : 0.12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.22)),
      ),
      child: Icon(icon, color: color.withValues(alpha: 0.95), size: 22),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.points,
    required this.color,
    required this.dim,
    required this.brightness,
  });

  final List<double> points; // 0..1
  final Color color;
  final bool dim;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B0E13) : const Color(0xFFF1F5FA);
    final bg = Paint()..color = bgColor;
    canvas.drawRect(Offset.zero & size, bg);

    _drawGrid(canvas, size, isDark);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = (1.0 - points[i]) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final baseColor = dim ? (isDark ? Colors.white24 : Colors.black26) : color;

    // Glow nhẹ
    for (final w in [5.0, 3.0]) {
      final glow = Paint()
        ..color = baseColor.withValues(alpha: 
          isDark ? (dim ? 0.10 : 0.18) : (dim ? 0.08 : 0.14),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glow);
    }

    // Main stroke
    final stroke = Paint()
      ..color = baseColor.withValues(alpha: dim ? 0.65 : 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, stroke);
  }

  void _drawGrid(Canvas canvas, Size size, bool isDark) {
    final small = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.04 : 0.05)
      ..strokeWidth = 1;

    final big = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.07 : 0.08)
      ..strokeWidth = 1;

    const smallStep = 18.0;
    const bigEvery = 5;

    for (double x = 0; x <= size.width; x += smallStep) {
      final p = ((x / smallStep).round() % bigEvery == 0) ? big : small;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += smallStep) {
      final p = ((y / smallStep).round() % bigEvery == 0) ? big : small;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.dim != dim ||
        oldDelegate.brightness != brightness;
  }
}

List<double> _clamp01(List<double> input) {
  return input.map((v) => v.isFinite ? v.clamp(0.0, 1.0) : 0.5).toList();
}

List<double> _demoWave(VitalType type, {required bool hasSignal, int n = 200}) {
  if (!hasSignal) {
    return List<double>.generate(n, (i) {
      final t = i / (n - 1);
      return 0.52 + 0.01 * math.sin(t * math.pi * 8);
    });
  }

  switch (type) {
    case VitalType.hr:
      final pattern = <double>[
        0.52, 0.52, 0.53, 0.51,
        0.55, 0.68, 0.20, 0.78, 0.40,
        0.52, 0.54, 0.52,
      ];
      return List<double>.generate(
        n,
            (i) => pattern[i % pattern.length].clamp(0.0, 1.0),
      );

    case VitalType.spo2:
      return List<double>.generate(n, (i) {
        final t = i / (n - 1);
        final cyc = (t * 6) % 1.0;
        final up = math.pow(cyc, 0.35).toDouble();
        final down = math.pow(1.0 - cyc, 1.6).toDouble();
        final wave = 0.28 + 0.55 * (0.65 * up + 0.35 * down);
        return wave.clamp(0.0, 1.0);
      });

    case VitalType.rr:
      return List<double>.generate(n, (i) {
        final t = i / (n - 1);
        final wave = 0.50 + 0.22 * math.sin(t * math.pi * 2 * 2.0);
        return wave.clamp(0.0, 1.0);
      });

    case VitalType.temp:
      return List<double>.generate(n, (i) {
        final t = i / (n - 1);
        final wave = 0.50 + 0.03 * math.sin(t * math.pi * 2 * 1.5);
        return wave.clamp(0.0, 1.0);
      });
  }
}
