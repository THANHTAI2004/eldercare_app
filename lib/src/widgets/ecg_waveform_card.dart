import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/ecg_reading.dart';

const int _historySegmentGapSlots = 24;

class EcgWaveformCard extends StatelessWidget {
  const EcgWaveformCard({super.key, required this.reading});

  final EcgReading reading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quality = reading.quality?.trim();
    final qualityLabel = quality == null || quality.isEmpty
        ? 'Không rõ'
        : quality;
    final heartRateLabel = reading.ecgHr?.toString() ?? '--';
    final samplingLabel = reading.samplingRate?.toString() ?? '--';
    final recordedText = DateFormat(
      'HH:mm:ss dd/MM',
    ).format(reading.recordedAt.toLocal());
    const chartHeight = 220.0;
    const chartPadding = 12.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Text(
                        'ECG',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cập nhật lúc $recordedText',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (reading.leadOff == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Tuột điện cực',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaChip(label: 'Sampling', value: '$samplingLabel Hz'),
                _MetaChip(label: 'Chất lượng', value: qualityLabel),
                _MetaChip(label: 'ECG HR', value: '$heartRateLabel bpm'),
                _MetaChip(
                  label: 'Mẫu sóng',
                  value: '${reading.waveform.length} điểm',
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = math.max(
                  0.0,
                  constraints.maxWidth - (chartPadding * 2),
                );
                final chartWidth = _preferredWaveformWidth(
                  availableWidth,
                  reading.waveform.length,
                );
                final canScroll = chartWidth > availableWidth + 1;

                return _WaveformChartSurface(
                  chartHeight: chartHeight,
                  chartPadding: chartPadding,
                  chartWidth: chartWidth,
                  showScrollbar: canScroll,
                  helperText:
                      'Kéo thanh ngang bên dưới để xem đầy đủ sóng ECG khi dữ liệu dài.',
                  child: CustomPaint(
                    painter: _EcgWaveformPainter(
                      waveform: reading.waveform,
                      lineColor: scheme.primary,
                      gridColor: scheme.outline.withValues(alpha: 0.22),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EcgHistoryWaveformCard extends StatelessWidget {
  const EcgHistoryWaveformCard({super.key, required this.readings});

  final List<EcgReading> readings;

  @override
  Widget build(BuildContext context) {
    final validReadings = readings
        .where((reading) => reading.waveform.isNotEmpty)
        .toList(growable: false);
    if (validReadings.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final firstRecorded = validReadings.first.recordedAt.toLocal();
    final lastRecorded = validReadings.last.recordedAt.toLocal();
    final totalSamples = validReadings.fold<int>(
      0,
      (sum, reading) => sum + reading.waveform.length,
    );
    final leadOffCount = validReadings
        .where((reading) => reading.leadOff == true)
        .length;
    final averageHr = _averageEcgHr(validReadings);
    const chartHeight = 260.0;
    const chartPadding = 12.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch sử ECG', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Đã ghép ${validReadings.length} lần đo trong ngày thành một biểu đồ dài để kéo xem dễ hơn.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaChip(label: 'Lần đo', value: '${validReadings.length}'),
                _MetaChip(label: 'Tổng điểm', value: '$totalSamples'),
                _MetaChip(
                  label: 'Bắt đầu',
                  value: DateFormat('HH:mm:ss').format(firstRecorded),
                ),
                _MetaChip(
                  label: 'Kết thúc',
                  value: DateFormat('HH:mm:ss').format(lastRecorded),
                ),
                if (averageHr != null)
                  _MetaChip(
                    label: 'ECG HR TB',
                    value: '${averageHr.round()} bpm',
                  ),
                if (leadOffCount > 0)
                  _MetaChip(label: 'Tuột điện cực', value: '$leadOffCount lần'),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final totalSlots = _totalHistorySlotCount(validReadings);
                final availableWidth = math.max(
                  0.0,
                  constraints.maxWidth - (chartPadding * 2),
                );
                final chartWidth = _preferredWaveformWidth(
                  availableWidth,
                  totalSlots,
                );
                final canScroll = chartWidth > availableWidth + 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WaveformChartSurface(
                      chartHeight: chartHeight,
                      chartPadding: chartPadding,
                      chartWidth: chartWidth,
                      showScrollbar: canScroll,
                      helperText:
                          'Kéo thanh ngang bên dưới để xem tiếp dữ liệu ECG khi biểu đồ dài.',
                      child: CustomPaint(
                        painter: _EcgHistoryPainter(
                          readings: validReadings,
                          lineColor: scheme.primary,
                          gridColor: scheme.outline.withValues(alpha: 0.22),
                          dividerColor: scheme.outline.withValues(alpha: 0.36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('HH:mm:ss').format(firstRecorded),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm:ss').format(lastRecorded),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformChartSurface extends StatelessWidget {
  const _WaveformChartSurface({
    required this.chartHeight,
    required this.chartPadding,
    required this.chartWidth,
    required this.showScrollbar,
    required this.helperText,
    required this.child,
  });

  final double chartHeight;
  final double chartPadding;
  final double chartWidth;
  final bool showScrollbar;
  final String helperText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showScrollbar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              helperText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        SizedBox(
          height: chartHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _HorizontalWaveformScroller(
                showScrollbar: showScrollbar,
                child: Padding(
                  padding: EdgeInsets.all(chartPadding),
                  child: SizedBox(
                    width: chartWidth,
                    height: chartHeight - (chartPadding * 2),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HorizontalWaveformScroller extends StatefulWidget {
  const _HorizontalWaveformScroller({
    required this.child,
    required this.showScrollbar,
  });

  final Widget child;
  final bool showScrollbar;

  @override
  State<_HorizontalWaveformScroller> createState() =>
      _HorizontalWaveformScrollerState();
}

class _HorizontalWaveformScrollerState
    extends State<_HorizontalWaveformScroller> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: widget.showScrollbar,
      trackVisibility: widget.showScrollbar,
      interactive: widget.showScrollbar,
      thickness: 10,
      radius: const Radius.circular(999),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}

double _preferredWaveformWidth(double availableWidth, int sampleCount) {
  if (sampleCount <= 1) return availableWidth;

  final spacing = switch (sampleCount) {
    <= 160 => 3.4,
    <= 320 => 2.6,
    <= 640 => 2.0,
    <= 1200 => 1.6,
    <= 2400 => 1.35,
    <= 6000 => 1.25,
    <= 12000 => 1.18,
    _ => 1.1,
  };

  final targetWidth = 40 + ((sampleCount - 1) * spacing);
  return math.min(math.max(availableWidth, targetWidth), 32000.0);
}

int _totalHistorySlotCount(List<EcgReading> readings) {
  final validReadings = readings
      .where((reading) => reading.waveform.isNotEmpty)
      .toList(growable: false);
  if (validReadings.isEmpty) return 0;

  var total = 0;
  for (var index = 0; index < validReadings.length; index++) {
    total += validReadings[index].waveform.length;
    if (index < validReadings.length - 1) {
      total += _historySegmentGapSlots;
    }
  }
  return total;
}

double? _averageEcgHr(List<EcgReading> readings) {
  final values = readings
      .map((reading) => reading.ecgHr)
      .whereType<int>()
      .toList(growable: false);
  if (values.isEmpty) return null;

  final total = values.fold<int>(0, (sum, value) => sum + value);
  return total / values.length;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EcgWaveformPainter extends CustomPainter {
  _EcgWaveformPainter({
    required this.waveform,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> waveform;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 1; i < 6; i++) {
      final dx = size.width * i / 6;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (var i = 1; i < 4; i++) {
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    if (waveform.isEmpty) return;

    double minValue = waveform.first;
    double maxValue = waveform.first;
    for (final sample in waveform.skip(1)) {
      minValue = math.min(minValue, sample);
      maxValue = math.max(maxValue, sample);
    }

    var range = maxValue - minValue;
    if (range.abs() < 0.0001) {
      range = 1;
      minValue -= 0.5;
    }

    final path = Path();
    for (var i = 0; i < waveform.length; i++) {
      final x = waveform.length == 1
          ? size.width / 2
          : size.width * i / (waveform.length - 1);
      final normalized = (waveform[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EcgWaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _EcgHistoryPainter extends CustomPainter {
  _EcgHistoryPainter({
    required this.readings,
    required this.lineColor,
    required this.gridColor,
    required this.dividerColor,
  });

  final List<EcgReading> readings;
  final Color lineColor;
  final Color gridColor;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 1; i < 6; i++) {
      final dx = size.width * i / 6;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (var i = 1; i < 4; i++) {
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final validReadings = readings
        .where((reading) => reading.waveform.isNotEmpty)
        .toList(growable: false);
    if (validReadings.isEmpty) return;

    double? minValue;
    double? maxValue;
    for (final reading in validReadings) {
      for (final sample in reading.waveform) {
        minValue = minValue == null ? sample : math.min(minValue, sample);
        maxValue = maxValue == null ? sample : math.max(maxValue, sample);
      }
    }
    if (minValue == null || maxValue == null) return;

    var range = maxValue - minValue;
    if (range.abs() < 0.0001) {
      range = 1;
      minValue -= 0.5;
    }

    final totalSlots = _totalHistorySlotCount(validReadings);
    if (totalSlots <= 0) return;

    final stepX = totalSlots <= 1 ? 0.0 : size.width / (totalSlots - 1);
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dividerPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.2;

    var slotIndex = 0;
    for (
      var readingIndex = 0;
      readingIndex < validReadings.length;
      readingIndex++
    ) {
      final waveform = validReadings[readingIndex].waveform;
      final path = Path();

      for (var sampleIndex = 0; sampleIndex < waveform.length; sampleIndex++) {
        final x = totalSlots <= 1
            ? size.width / 2
            : (slotIndex + sampleIndex) * stepX;
        final normalized = (waveform[sampleIndex] - minValue) / range;
        final y = size.height - (normalized * size.height);
        if (sampleIndex == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, linePaint);
      slotIndex += waveform.length;

      if (readingIndex < validReadings.length - 1) {
        final dividerX = totalSlots <= 1 ? size.width / 2 : slotIndex * stepX;
        canvas.drawLine(
          Offset(dividerX, 0),
          Offset(dividerX, size.height),
          dividerPaint,
        );
        slotIndex += _historySegmentGapSlots;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EcgHistoryPainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dividerColor != dividerColor;
  }
}
