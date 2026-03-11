import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// ECG waveform chart widget
class EcgChart extends StatelessWidget {
  final List<double> waveform;
  final int? heartRate;
  final String quality;

  const EcgChart({
    super.key,
    required this.waveform,
    this.heartRate,
    this.quality = 'good',
  });

  @override
  Widget build(BuildContext context) {
    // Limit data points to prevent performance issues
    // Show last 2500 points (10 seconds at 250Hz)
    final displayData = waveform.length > 2500
        ? waveform.sublist(waveform.length - 2500)
        : waveform;

    final spots = displayData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ECG Realtime',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (heartRate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$heartRate BPM',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    _buildQualityBadge(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ECG Chart
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? Center(
                      child: Text(
                        'Đang chờ dữ liệu ECG...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 0.5,
                          verticalInterval: spots.length / 10,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.red.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Colors.red.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        minX: 0,
                        maxX: spots.length.toDouble(),
                        minY: _getMinY(displayData),
                        maxY: _getMaxY(displayData),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: false,
                            color: Colors.red,
                            barWidth: 2,
                            isStrokeCapRound: false,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                        lineTouchData: const LineTouchData(enabled: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityBadge() {
    Color color;
    String text;

    switch (quality.toLowerCase()) {
      case 'good':
        color = Colors.green;
        text = 'Tốt';
        break;
      case 'fair':
        color = Colors.orange;
        text = 'Trung bình';
        break;
      case 'poor':
        color = Colors.red;
        text = 'Kém';
        break;
      default:
        color = Colors.grey;
        text = 'N/A';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  double _getMinY(List<double> data) {
    if (data.isEmpty) return -1;
    final min = data.reduce((a, b) => a < b ? a : b);
    return min - 0.5; // Add padding
  }

  double _getMaxY(List<double> data) {
    if (data.isEmpty) return 1;
    final max = data.reduce((a, b) => a > b ? a : b);
    return max + 0.5; // Add padding
  }
}
