import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/ui/app_radius.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class ECGWaveformCard extends StatelessWidget {
  const ECGWaveformCard({
    super.key,
    required this.reading,
    this.title = 'Điện tâm đồ ECG',
  });

  final EcgReading reading;
  final String title;

  @override
  Widget build(BuildContext context) {
    final quality = (reading.quality ?? '').trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'HH:mm, dd/MM/yyyy',
                      ).format(reading.recordedAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: quality.isEmpty ? 'Không rõ chất lượng' : quality,
                tone: quality.toLowerCase() == 'good'
                    ? StatusTone.success
                    : StatusTone.info,
              ),
            ],
          ),
          if (reading.leadOff == true) ...[
            const SizedBox(height: AppSpacing.md),
            const StatusBadge(
              label: 'Điện cực chưa tiếp xúc tốt',
              tone: StatusTone.warning,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CustomPaint(
                    painter: _WavePainter(
                      samples: reading.waveform,
                      color: Theme.of(context).colorScheme.primary,
                      gridColor: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetaPill(
                label: 'Sampling rate',
                value: '${reading.samplingRate ?? '--'} Hz',
              ),
              _MetaPill(
                label: 'ECG HR',
                value: '${reading.ecgHr ?? '--'} bpm',
              ),
              _MetaPill(
                label: 'Mẫu sóng',
                value: '${reading.waveform.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.samples,
    required this.color,
    required this.gridColor,
  });

  final List<double> samples;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final dx = size.width * i / 6;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (var i = 1; i < 5; i++) {
      final dy = size.height * i / 5;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    if (samples.isEmpty) return;

    double minValue = samples.first;
    double maxValue = samples.first;
    for (final sample in samples.skip(1)) {
      minValue = math.min(minValue, sample);
      maxValue = math.max(maxValue, sample);
    }
    var range = maxValue - minValue;
    if (range.abs() < 0.0001) {
      range = 1;
      minValue -= 0.5;
    }

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = samples.length == 1
          ? size.width / 2
          : size.width * i / (samples.length - 1);
      final y = size.height -
          (((samples[i] - minValue) / range).clamp(0.0, 1.0) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor;
  }
}
