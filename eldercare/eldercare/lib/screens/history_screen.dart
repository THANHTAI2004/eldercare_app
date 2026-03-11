import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/config.dart';
import '../models/health_reading.dart';
import '../services/api_service.dart';

/// History screen for viewing historical data
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<HealthReading> _readings = [];
  bool _isLoading = true;
  String _selectedPeriod = '24h';
  int _selectedTab = 0;
  String? _errorMessage;
  bool _isApiConnected = false;

  final List<String> _periods = ['1h', '6h', '24h', '7d', '30d'];
  final List<String> _tabs = ['SpO2', 'Nhịp tim', 'Nhịp thở', 'Nhiệt độ'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check API connection first
    _isApiConnected = await _apiService.healthCheck();
    if (!_isApiConnected) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Không kết nối được tới server\nVui lòng kiểm tra:\n- Server đang chạy tại ${AppConfig.apiBaseUrl}\n- Network connection';
        });
      }
      return;
    }

    try {
      // Calculate time range based on period
      final endTime = DateTime.now();
      DateTime startTime;

      switch (_selectedPeriod) {
        case '1h':
          startTime = endTime.subtract(const Duration(hours: 1));
          break;
        case '6h':
          startTime = endTime.subtract(const Duration(hours: 6));
          break;
        case '24h':
          startTime = endTime.subtract(const Duration(hours: 24));
          break;
        case '7d':
          startTime = endTime.subtract(const Duration(days: 7));
          break;
        case '30d':
          startTime = endTime.subtract(const Duration(days: 30));
          break;
        default:
          startTime = endTime.subtract(const Duration(hours: 24));
      }

      final readings = await _apiService.getVitals(
        deviceUid: AppConfig.defaultDeviceUid,
        limit: 1000,
        startTime: startTime,
        endTime: endTime,
      );

      if (mounted) {
        setState(() {
          _readings = readings
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi khi tải dữ liệu: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch sử dữ liệu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Tải lại',
          ),
          // Connection status
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    _isApiConnected ? Icons.cloud_done : Icons.cloud_off,
                    size: 20,
                    color: _isApiConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isApiConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isApiConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Khoảng thời gian:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periods.map((period) {
                        final isSelected = period == _selectedPeriod;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_formatPeriod(period)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedPeriod = period;
                                });
                                _loadData();
                              }
                            },
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metric selector buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = index == _selectedTab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tab),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTab = index;
                          });
                        }
                      },
                      selectedColor: _getChartColor(),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Chart
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Server: ${AppConfig.apiBaseUrl}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _readings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_chart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có dữ liệu trong khoảng thời gian này',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thử chọn khoảng thời gian khác',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildChart(),
                        const SizedBox(height: 20),
                        _buildStatistics(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = _getSpots();

    if (spots.isEmpty) {
      return const SizedBox();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tabs[_selectedTab],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getInterval(),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _readings.length)
                            return const Text('');
                          final reading = _readings[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('HH:mm').format(reading.timestamp),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: _getChartColor(),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: spots.length <= 50,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: _getChartColor(),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _getChartColor().withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} ${_getUnit()}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final values = _getValues();
    if (values.isEmpty) return const SizedBox();

    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thống kê',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Trung bình',
                  avg.toStringAsFixed(1),
                  Colors.blue,
                ),
                _buildStatItem(
                  'Thấp nhất',
                  min.toStringAsFixed(1),
                  Colors.green,
                ),
                _buildStatItem('Cao nhất', max.toStringAsFixed(1), Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tổng số lần đo: ${_readings.length}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          '$value ${_getUnit()}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getSpots() {
    return _readings
        .asMap()
        .entries
        .map((entry) {
          final value = _getValue(entry.value);
          return value != null ? FlSpot(entry.key.toDouble(), value) : null;
        })
        .whereType<FlSpot>()
        .toList();
  }

  List<double> _getValues() {
    return _readings.map((r) => _getValue(r)).whereType<double>().toList();
  }

  double? _getValue(HealthReading reading) {
    switch (_selectedTab) {
      case 0:
        return reading.spo2;
      case 1:
        return reading.heartRate?.toDouble();
      case 2:
        return reading.respiratoryRate?.toDouble();
      case 3:
        return reading.temperature;
      default:
        return null;
    }
  }

  String _getUnit() {
    switch (_selectedTab) {
      case 0:
        return '%';
      case 1:
        return 'BPM';
      case 2:
        return '/phút';
      case 3:
        return '°C';
      default:
        return '';
    }
  }

  Color _getChartColor() {
    switch (_selectedTab) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.red;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  double _getInterval() {
    switch (_selectedTab) {
      case 0:
        return 5; // SpO2
      case 1:
        return 20; // Heart rate
      case 2:
        return 5; // Respiratory rate
      case 3:
        return 1; // Temperature
      default:
        return 1;
    }
  }

  String _formatPeriod(String period) {
    switch (period) {
      case '1h':
        return '1 giờ';
      case '6h':
        return '6 giờ';
      case '24h':
        return '24 giờ';
      case '7d':
        return '7 ngày';
      case '30d':
        return '30 ngày';
      default:
        return period;
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
