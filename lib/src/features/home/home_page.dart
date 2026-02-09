import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/widgets/feature_button.dart';
import 'package:eldercare_app/src/widgets/health_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _didInit = false;
  Timer? _refreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final device = context.read<DeviceProvider>().current;
      final realtime = context.read<RealtimeProvider>();

      // init với userId của thiết bị hiện tại
      realtime.init(userId: device?.id);

      // auto refresh latest
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        final rt = context.read<RealtimeProvider>();
        if (!rt.isLoadingLatest && rt.hasUser) {
          rt.refreshLatest();
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _deviceLabel(dynamic device) {
    if (device == null) return 'Chưa chọn thiết bị';

    final name = (device.name ?? '').toString().trim();
    final id = (device.id ?? '').toString().trim();

    if (name.isEmpty) return 'Thiết bị $id';

    // tránh kiểu "Thiết bị u01 • u01"
    final ln = name.toLowerCase();
    final lid = id.toLowerCase();
    if (ln.contains(lid)) return name;

    return '$name • $id';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RealtimeProvider>();
    final device = context.watch<DeviceProvider>().current;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eldercare'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Đổi thiết bị',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
            icon: const Icon(Icons.devices),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: p.isLoadingLatest ? null : () => p.refreshLatest(),
            icon: const Icon(Icons.refresh),
          ),
        ],

        // ✅ tên thiết bị + badge để ở đây -> không bao giờ bị mất
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _deviceLabel(device),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (device != null)
                  _OnlineBadge(
                    isOnline: p.isOnline,
                    text: p.lastSeenText,
                  ),
              ],
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: device == null
            ? _buildNoDeviceView(context)
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (p.error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p.error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ✅ 1) Thông số mới nhất
              HealthCard(point: p.latest),
              const SizedBox(height: 16),

              // ✅ 2) History (full width)
              FeatureButton(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Theo ngày/giờ',
                onTap: () => Navigator.pushNamed(context, AppRoutes.history),
              ),

              const SizedBox(height: 16),

              // ✅ 3) ECG nằm dưới + to hơn (full width)
              EcgCard(point: p.latest, waveHeight: 240),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDeviceView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          const Text(
            'Chưa chọn thiết bị',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vào mục Thiết bị để thêm hoặc chọn một thiết bị\n'
                'sau đó quay lại đây để xem chỉ số.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
            icon: const Icon(Icons.settings_input_antenna),
            label: const Text('Quản lý thiết bị'),
          ),
        ],
      ),
    );
  }
}

/// ✅ Badge Online/Offline
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.isOnline, required this.text});

  final bool isOnline;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = isOnline ? scheme.primaryContainer : scheme.errorContainer;
    final fg = isOnline ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Hoạt động • $text' : 'Mất kết nối • $text',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card hiển thị ECG
class EcgCard extends StatelessWidget {
  const EcgCard({
    super.key,
    required this.point,
    this.waveHeight = 200,
  });

  final VitalPoint? point;
  final double waveHeight;

  @override
  Widget build(BuildContext context) {
    final p = point;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hr = p?.hr;
    final leadOff = p?.leadOff;

    String leadText;
    Color leadColor;
    bool disabled;

    if (p == null) {
      leadText = 'Chưa có dữ liệu ECG';
      leadColor = scheme.outline;
      disabled = true;
    } else if (leadOff == 1) {
      leadText = 'Chưa gắn điện cực ngực';
      leadColor = scheme.error;
      disabled = true;
    } else {
      leadText = hr == null ? 'Điện cực OK' : 'Điện cực OK • HR ~ $hr bpm';
      leadColor = scheme.primary;
      disabled = false;
    }

    Color a(Color c, double alpha) => c.withValues(alpha: alpha);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ECG điện tâm đồ', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tín hiệu ECG từ cảm biến ngực (AD8232).',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Waveform to hơn + full width
            SizedBox(
              height: waveHeight,
              width: double.infinity,
              child: EcgWave(
                color: disabled ? a(scheme.outline, 0.6) : scheme.primary,
                background: a(scheme.surfaceContainerHighest, 0.55),
                thickness: 2.4,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: a(leadColor, 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: a(leadColor, 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    disabled ? Icons.highlight_off : Icons.favorite_border,
                    size: 18,
                    color: leadColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    leadText,
                    style: textTheme.bodySmall?.copyWith(
                      color: leadColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcgWave extends StatelessWidget {
  const EcgWave({
    super.key,
    required this.color,
    required this.background,
    this.thickness = 2.0,
  });

  final Color color;
  final Color background;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EcgPainter(
        color: color,
        background: background,
        thickness: thickness,
      ),
      size: Size.infinite,
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({
    required this.color,
    required this.background,
    required this.thickness,
  });

  final Color color;
  final Color background;
  final double thickness;

  List<double> _basePattern() {
    return [
      0, 0, 0,
      0.1, 0.2, 0.1, 0,
      0, 0, -0.2,
      1.0,
      -0.4, 0, 0.05,
      0.2, 0.1, 0,
      0, 0, 0, 0, 0,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bgPaint,
    );

    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final pattern = _basePattern();
    const repeat = 6; // ✅ nhiều nhịp hơn cho khung rộng
    final samples = <double>[];
    for (int r = 0; r < repeat; r++) {
      samples.addAll(pattern);
    }

    final n = samples.length;
    if (n < 2) return;

    final midY = h / 2;
    final amp = h * 0.42; // ✅ to hơn

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = w * i / (n - 1);
      final y = midY - samples[i] * amp;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.background != background ||
        oldDelegate.thickness != thickness;
  }
}
