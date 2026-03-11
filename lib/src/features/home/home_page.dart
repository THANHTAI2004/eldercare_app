import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/widgets/feature_button.dart';
import 'package:eldercare_app/src/widgets/medical_monitor_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _boundUserId;

  String _deviceLabel(dynamic device) {
    if (device == null) return 'Chưa chọn thiết bị';

    final name = (device.name ?? '').toString().trim();
    final id = (device.id ?? '').toString().trim();

    if (name.isEmpty) return 'Thiết bị $id';

    final ln = name.toLowerCase();
    final lid = id.toLowerCase();
    if (ln.contains(lid)) return name;

    return '$name • $id';
  }

  void _syncRealtime() {
    final current = context.read<DeviceProvider>().current;
    final userId = current?.id ?? '';
    final deviceId = current?.resolvedDeviceId ?? '';
    if (_boundUserId == userId) return;
    _boundUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context
          .read<RealtimeProvider>()
          .init(userId: userId, deviceId: deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>().current;
    final rt = context.watch<RealtimeProvider>();
    _syncRealtime();

    final latest = rt.latest;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Eldercare'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Đổi thiết bị',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
            icon: const Icon(Icons.devices),
          ),
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            onPressed: rt.isLoadingLatest ? null : () => rt.refreshLatest(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _deviceLabel(device),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
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
                    SizedBox(
                      height: 360,
                      child: MedicalMonitorPanel(
                        brightness: Brightness.light,
                        hr: latest?.hr?.toDouble(),
                        spo2: latest?.spo2?.toDouble(),
                        temp: latest?.temp,
                        rr: latest?.rr?.toDouble(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rt.hasUser ? 'Cập nhật: ${rt.lastSeenText}' : 'Chưa có user đang theo dõi',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FeatureButton(
                      icon: Icons.history,
                      title: 'History',
                      subtitle: 'Xem lịch sử theo ngày',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.history),
                    ),
                    const SizedBox(height: 16),
                    FeatureButton(
                      icon: Icons.devices,
                      title: 'Thiết bị',
                      subtitle: 'Quản lý thiết bị của bạn',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.devices),
                    ),
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
            'sau đó quay lại đây để xem dữ liệu.',
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
