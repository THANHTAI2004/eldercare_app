import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/feature_button.dart';
import 'package:eldercare_app/src/widgets/medical_monitor_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastBindingKey;

  String _deviceLabel(Device? device) {
    if (device == null) return 'Chua chon thiet bi';

    final name = device.name.trim();
    final id = device.resolvedDeviceId;

    if (name.isEmpty) return 'Thiet bi $id';

    final ln = name.toLowerCase();
    final lid = id.toLowerCase();
    if (ln.contains(lid)) return name;

    return '$name • $id';
  }

  void _syncRealtime() {
    final current = context.read<DeviceProvider>().current;
    final session = context.read<SessionProvider>();
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final userId = current?.primaryUserId ?? session.authenticatedUserId;
    final deviceId = current?.resolvedDeviceId ?? '';
    final bindingKey = '$userId::$deviceId';
    if (_lastBindingKey == bindingKey) return;
    _lastBindingKey = bindingKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RealtimeProvider>().init(
        userId: userId,
        deviceId: deviceId,
      );
      await history.bindScope(
        userId: userId,
        deviceId: deviceId,
        dayLocal: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
        load: true,
      );
      ecg.bindScope(userId: userId, deviceId: deviceId);
    });
  }

  Future<void> _requestEcg(Device device) async {
    final rt = context.read<RealtimeProvider>();
    final ecg = context.read<EcgProvider>();

    try {
      ecg.bindScope(
        userId: device.primaryUserId,
        deviceId: device.resolvedDeviceId,
      );
      final result = await ecg.requestEcg();
      await rt.refreshLatest(silent: true);
      if (!mounted) return;
      final message =
          result['message']?.toString() ??
          ecg.message ??
          'Da gui lenh ECG thanh cong. Dang cho ket qua moi.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ecg.error ?? '$e')));
    }
  }

  Future<void> _selectDevice(String? selectedDeviceId) async {
    if (selectedDeviceId == null || selectedDeviceId.trim().isEmpty) return;

    final deviceProvider = context.read<DeviceProvider>();
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final rt = context.read<RealtimeProvider>();
    final session = context.read<SessionProvider>();
    await deviceProvider.setCurrent(selectedDeviceId);

    final current = deviceProvider.current;
    if (current == null) return;

    await rt.changeUser(
      current.primaryUserId ?? session.authenticatedUserId,
      deviceId: current.resolvedDeviceId,
    );
    await history.bindScope(
      userId: current.primaryUserId ?? session.authenticatedUserId,
      deviceId: current.resolvedDeviceId,
      dayLocal: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      load: true,
    );
    ecg.bindScope(
      userId: current.primaryUserId ?? session.authenticatedUserId,
      deviceId: current.resolvedDeviceId,
    );
  }

  Future<void> _refreshAll() async {
    final rt = context.read<RealtimeProvider>();
    final history = context.read<HistoryProvider>();
    await rt.refreshLatest();
    await history.loadForDay(
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final devices = deviceProvider.devices;
    final device = deviceProvider.current;
    final ecg = context.watch<EcgProvider>();
    final history = context.watch<HistoryProvider>();
    final session = context.watch<SessionProvider>();
    final rt = context.watch<RealtimeProvider>();
    _syncRealtime();

    final latest = rt.latest;
    final hasLatest = latest != null;

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
            tooltip: 'Canh bao',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.alerts),
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Doi thiet bi',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
            icon: const Icon(Icons.devices),
          ),
          IconButton(
            tooltip: 'Lam moi du lieu',
            onPressed: rt.isLoadingLatest ? null : _refreshAll,
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: device == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [_buildNoDeviceView(context, rt)],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _DeviceSelectorCard(
                      devices: devices,
                      currentDeviceId: device.id,
                      isSyncing: deviceProvider.isSyncing,
                      onChanged: _selectDevice,
                      onOpenList: () =>
                          Navigator.pushNamed(context, AppRoutes.devices),
                    ),
                    const SizedBox(height: 16),
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
                        rt.hasUser
                            ? 'Cap nhat: ${rt.lastSeenText}'
                            : 'Chua co user dang theo doi',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (rt.error != null && rt.error!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      if (rt.isShowingCachedLatest)
                        _InfoBanner(message: rt.error!)
                      else
                        _ErrorBanner(
                          message: rt.error!,
                          actionLabel: rt.hasSessionExpiredError ||
                                  !session.isAuthenticated
                              ? 'Dang nhap lai'
                              : rt.hasPermissionError
                              ? 'Doi thiet bi'
                              : null,
                          onAction: rt.hasSessionExpiredError ||
                                  !session.isAuthenticated
                              ? () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.devices,
                                )
                              : rt.hasPermissionError
                              ? () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.devices,
                                )
                              : null,
                        ),
                    ],
                    if (history.isShowingCachedHistory &&
                        (rt.error == null || rt.error!.trim().isEmpty)) ...[
                      const SizedBox(height: 12),
                      const _InfoBanner(
                        message:
                            'Lich su trong ngay hien dang dung du lieu luu tam.',
                      ),
                    ],
                    if (ecg.message != null && ecg.message!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoBanner(message: ecg.message!),
                    ],
                    if (!device.hasExplicitDeviceId) ...[
                      const SizedBox(height: 12),
                      const _InfoBanner(
                        message:
                            'Thiet bi nay dang o che do fallback dev, ECG co the khong hoat dong dung contract server.',
                      ),
                    ],
                    if (!hasLatest && rt.isLoadingLatest) ...[
                      const SizedBox(height: 12),
                      const _LoadingPanel(),
                    ] else if (!hasLatest && rt.latestStatus.isEmpty) ...[
                      const SizedBox(height: 12),
                      _EmptyPanel(
                        message: _noDataMessage(
                          rt: rt,
                          session: session,
                          device: device,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _EcgActionCard(
                      enabled:
                          device.hasExplicitDeviceId && !ecg.isLoading,
                      isLoading: ecg.isLoading,
                      onTap: () => _requestEcg(device),
                    ),
                    const SizedBox(height: 16),
                    FeatureButton(
                      icon: Icons.history,
                      title: 'History',
                      subtitle: 'Xem lich su theo ngay',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.history),
                    ),
                    const SizedBox(height: 16),
                    FeatureButton(
                      icon: Icons.notifications_active_outlined,
                      title: 'Canh bao',
                      subtitle: 'Xem va acknowledge alerts',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.alerts),
                    ),
                    const SizedBox(height: 16),
                    FeatureButton(
                      icon: Icons.devices,
                      title: 'Thiet bi',
                      subtitle: 'Quan ly thiet bi cua ban',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.devices),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _noDataMessage({
    required RealtimeProvider rt,
    required SessionProvider session,
    required Device device,
  }) {
    if (!session.isAuthenticated) {
      return 'Ban chua dang nhap. Vao muc Thiet bi de dang nhap va dong bo session.';
    }
    if (rt.hasPermissionError) {
      return 'Tai khoan hien tai khong co quyen xem device nay.';
    }
    if (rt.hasNoDataError) {
      return 'Device da duoc lien ket nhung chua co reading nao tren server.';
    }
    if (device.isLocalOnly) {
      return 'Day la device fallback debug. Neu dang o production, hay dang nhap va sync linked devices tu server.';
    }
    return 'Device da duoc chon nhung chua co du lieu moi nhat. Thu refresh lai sau khi thiet bi gui reading.';
  }

  Widget _buildNoDeviceView(BuildContext context, RealtimeProvider rt) {
    final session = context.watch<SessionProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            session.isAuthenticated ? 'Chua chon thiet bi' : 'Chua dang nhap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            session.isAuthenticated
                ? 'Tai khoan da dang nhap nhung chua co device duoc chon.\nMo muc Thiet bi de chon device dang theo doi.'
                : 'Ban can dang nhap truoc, sau do app se tai danh sach device da lien ket tu server.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
            icon: Icon(
              session.isAuthenticated
                  ? Icons.settings_input_antenna
                  : Icons.login,
            ),
            label: Text(
              session.isAuthenticated ? 'Quan ly thiet bi' : 'Dang nhap',
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSelectorCard extends StatelessWidget {
  const _DeviceSelectorCard({
    required this.devices,
    required this.currentDeviceId,
    required this.isSyncing,
    required this.onChanged,
    required this.onOpenList,
  });

  final List<Device> devices;
  final String currentDeviceId;
  final bool isSyncing;
  final ValueChanged<String?> onChanged;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    Device? current;
    for (final device in devices) {
      if (device.id == currentDeviceId) {
        current = device;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Thiet bi dang theo doi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue:
                  devices.any((device) => device.id == currentDeviceId)
                  ? currentDeviceId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Chon device',
                prefixIcon: Icon(Icons.devices),
              ),
              items: devices
                  .map(
                    (device) => DropdownMenuItem<String>(
                      value: device.id,
                      child: Text(
                        '${device.name} (${device.resolvedDeviceId})',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: devices.length <= 1 ? null : onChanged,
            ),
            const SizedBox(height: 8),
            Text(
              current == null
                  ? 'Chua co device hien tai.'
                  : 'User chinh: ${current.primaryUserId ?? 'khong ro'} • Linked users: ${current.linkedUsers.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenList,
                icon: const Icon(Icons.list_alt),
                label: const Text('Mo danh sach day du'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Dang tai du lieu moi nhat...'),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EcgActionCard extends StatelessWidget {
  const _EcgActionCard({
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ECG On-demand',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? 'Gui lenh do ECG cho thiet bi dang chon.'
                  : 'Can deviceId that de gui lenh ECG.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: enabled ? onTap : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.favorite_outline),
              label: Text(isLoading ? 'Dang gui lenh...' : 'Yeu cau ECG'),
            ),
          ],
        ),
      ),
    );
  }
}
