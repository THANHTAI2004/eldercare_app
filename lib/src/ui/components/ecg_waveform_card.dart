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
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            width: double.infinity,
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

class ContinuousEcgCard extends StatelessWidget {
  const ContinuousEcgCard({super.key, required this.title, required this.readings});

  final String title;
  final List<EcgReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();

    final List<double> combinedWaveform = [];
    final List<Map<String, dynamic>> recordMarkers = [];
    int currentSampleIndex = 0;

    for (final r in readings) {
      if (r.waveform.isNotEmpty) {
        if (combinedWaveform.isNotEmpty) {
          combinedWaveform.add(double.nan); // gap marker
          currentSampleIndex++;
        }
        
        recordMarkers.add({
          'time': r.recordedAt.toLocal(),
          'startIndex': currentSampleIndex,
        });

        combinedWaveform.addAll(r.waveform);
        currentSampleIndex += r.waveform.length;
      }
    }

    if (combinedWaveform.isEmpty) return const SizedBox.shrink();

    double minValue = 0;
    double maxValue = 0;
    final validSamples = combinedWaveform.where((s) => !s.isNaN);
    if (validSamples.isNotEmpty) {
      minValue = validSamples.first;
      maxValue = validSamples.first;
      for (final s in validSamples) {
        if (s < minValue) minValue = s;
        if (s > maxValue) maxValue = s;
      }
      final range = maxValue - minValue;
      if (range.abs() < 0.0001) {
        minValue -= 0.5;
        maxValue += 0.5;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
              final chartWidth = (combinedWaveform.length * 1.5).clamp(screenWidth, double.infinity);
              
              return SizedBox(
                height: 180,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 12, right: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Trục dọc (Y-axis)
                        SizedBox(
                          width: 36,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24), // Reserve space for X-axis text
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(maxValue.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                Text(((maxValue + minValue) / 2).toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                Text(minValue.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                        // Đồ thị cuộn ngang và Trục X
                        Expanded(
                          child: ClipRRect(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: chartWidth,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Đồ thị chính
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        bottom: 24, // Space for X-axis
                                        child: CustomPaint(
                                          painter: _ContinuousWavePainter(
                                            samples: combinedWaveform,
                                            color: Theme.of(context).colorScheme.primary,
                                            gridColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28),
                                            minValue: minValue,
                                            maxValue: maxValue,
                                          ),
                                        ),
                                      ),
                                      // Trục ngang (X-axis)
                                      for (final marker in recordMarkers)
                                        Positioned(
                                          left: combinedWaveform.length > 1
                                              ? chartWidth * marker['startIndex'] / (combinedWaveform.length - 1)
                                              : 0,
                                          bottom: 0,
                                          child: Text(
                                            DateFormat('HH:mm').format(marker['time']),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetaPill(
                label: 'Tổng số mẫu',
                value: '${combinedWaveform.where((s) => !s.isNaN).length}',
              ),
              _MetaPill(
                label: 'Bản ghi',
                value: '${readings.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinuousWavePainter extends CustomPainter {
  _ContinuousWavePainter({
    required this.samples,
    required this.color,
    required this.gridColor,
    required this.minValue,
    required this.maxValue,
  });

  final List<double> samples;
  final Color color;
  final Color gridColor;
  final double minValue;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < (size.width / 40); i++) {
      final dx = i * 40.0;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    // Draw 3 horizontal grid lines corresponding to Max, Mid, Min
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    if (samples.isEmpty) return;

    var range = maxValue - minValue;
    if (range.abs() < 0.0001) {
      range = 1;
    }

    final path = Path();
    bool moveNext = true;
    for (var i = 0; i < samples.length; i++) {
      if (samples[i].isNaN) {
        moveNext = true;
        continue;
      }

      final x = samples.length == 1
          ? size.width / 2
          : size.width * i / (samples.length - 1);
      final y = size.height -
          (((samples[i] - minValue) / range).clamp(0.0, 1.0) * size.height);
      
      if (moveNext) {
        path.moveTo(x, y);
        moveNext = false;
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
  bool shouldRepaint(covariant _ContinuousWavePainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
