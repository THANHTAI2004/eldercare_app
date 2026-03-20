import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/core/app_layout.dart';
import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/features/devices/device_viewers_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/async_status.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/feature_button.dart';
import 'package:eldercare_app/src/widgets/medical_monitor_panel.dart';
import 'package:eldercare_app/src/widgets/responsive_two_pane.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastBindingKey;

  List<double>? _seriesForMetric(HistoryProvider history, Metric metric) {
    final metricPoints = history.metricPointsForSelectedDay(metric);
    if (metricPoints.isEmpty) return null;

    final values = metricPoints
        .map((point) => point.valueOf(metric))
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (values.isEmpty) return null;
    if (values.length <= 40) return values;

    return List<double>.generate(40, (index) {
      final sourceIndex = ((values.length - 1) * index / 39).round();
      return values[sourceIndex];
    }, growable: false);
  }

  String _deviceLabel(Device? device) {
    if (device == null) return 'Chưa chọn thiết bị';

    final name = device.name.trim();
    final id = device.resolvedDeviceId;

    if (name.isEmpty) return 'Thiết bị $id';

    final normalizedName = name.toLowerCase();
    final normalizedId = id.toLowerCase();
    if (normalizedName.contains(normalizedId)) return name;

    return '$name | $id';
  }

  void _syncRealtime() {
    final current = context.read<DeviceProvider>().current;
    final session = context.read<SessionProvider>();
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final deviceId = current?.resolvedDeviceId ?? '';
    final bindingKey = '${session.authenticatedUserId}::$deviceId';
    if (_lastBindingKey == bindingKey) return;
    _lastBindingKey = bindingKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RealtimeProvider>().init(deviceId: deviceId);
      await history.bindScope(
        deviceId: deviceId,
        dayLocal: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
        load: true,
      );
      ecg.bindScope(deviceId: deviceId);
    });
  }

  Future<void> _requestEcg(Device device) async {
    if (!device.isOwnerLink) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chỉ chủ thiết bị mới có thể yêu cầu đo ECG cho thiết bị này.',
          ),
        ),
      );
      return;
    }

    final realtime = context.read<RealtimeProvider>();
    final ecg = context.read<EcgProvider>();

    try {
      ecg.bindScope(deviceId: device.resolvedDeviceId);
      final result = await ecg.requestEcg();
      await realtime.refreshLatest(silent: true);
      if (!mounted) return;
      final message =
          result['message']?.toString() ??
          ecg.message ??
          'Đã gửi yêu cầu đo ECG thành công. Đang chờ kết quả mới.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ecg.error ?? '$error')),
      );
    }
  }

  Future<void> _selectDevice(String? selectedDeviceId) async {
    if (selectedDeviceId == null || selectedDeviceId.trim().isEmpty) return;

    final deviceProvider = context.read<DeviceProvider>();
    final history = context.read<HistoryProvider>();
    final ecg = context.read<EcgProvider>();
    final realtime = context.read<RealtimeProvider>();
    await deviceProvider.setCurrent(selectedDeviceId);

    final current = deviceProvider.current;
    if (current == null) return;

    await realtime.changeDevice(current.resolvedDeviceId);
    await history.bindScope(
      deviceId: current.resolvedDeviceId,
      dayLocal: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      load: true,
    );
    ecg.bindScope(deviceId: current.resolvedDeviceId);
  }

  Future<void> _refreshAll() async {
    final realtime = context.read<RealtimeProvider>();
    final history = context.read<HistoryProvider>();
    await realtime.refreshLatest();
    await history.loadForDay(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
  }

  Future<void> _openAlerts() async {
    final result = await Navigator.pushNamed(context, AppRoutes.alerts);
    final selectedDeviceId = result is String ? result.trim() : '';
    if (!mounted || selectedDeviceId.isEmpty) return;
    await _selectDevice(selectedDeviceId);
  }

  Future<void> _openOwnerManagement(Device device) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceViewersPage(device: device)),
    );
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    await context.read<DeviceProvider>().syncFromServer(
      authenticatedUserId: session.authenticatedUserId,
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
    final realtime = context.watch<RealtimeProvider>();
    _syncRealtime();

    final layout = AppLayout.of(context);
    final isCompact = layout == AppLayoutSize.compact;
    final isExpanded = layout == AppLayoutSize.expanded;
    final horizontalPadding = switch (layout) {
      AppLayoutSize.compact => 12.0,
      AppLayoutSize.medium => 20.0,
      AppLayoutSize.expanded => 24.0,
    };
    final sectionSpacing = switch (layout) {
      AppLayoutSize.compact => 12.0,
      AppLayoutSize.medium => 16.0,
      AppLayoutSize.expanded => 20.0,
    };
    final contentMaxWidth = AppLayout.maxContentWidth(context);
    final pagePadding = AppLayout.pagePadding(
      context,
      compact: 12,
      medium: 20,
      expanded: 24,
      bottom: 20,
    );
    final latest = realtime.latest;
    final hasLatest = latest != null;

    Widget buildDeviceContent() {
      final currentDevice = device!;
      final primaryChildren = <Widget>[
        MedicalMonitorPanel(
          brightness: Brightness.light,
          hr: latest?.hr?.toDouble(),
          spo2: latest?.spo2?.toDouble(),
          temp: latest?.temp,
          rr: latest?.rr?.toDouble(),
          hrWave: _seriesForMetric(history, Metric.hr),
          spo2Wave: _seriesForMetric(history, Metric.spo2),
          tempWave: _seriesForMetric(history, Metric.temp),
          rrWave: _seriesForMetric(history, Metric.rr),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            realtime.hasDevice
                ? 'Cập nhật: ${realtime.lastSeenText}'
                : 'Chưa có thiết bị đang theo dõi',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (realtime.error != null && realtime.error!.trim().isNotEmpty)
          _ErrorBanner(
            message: realtime.error!,
            actionLabel:
                realtime.hasSessionExpiredError || !session.isAuthenticated
                ? 'Đăng nhập lại'
                : realtime.hasPermissionError
                ? 'Đổi thiết bị'
                : null,
            onAction:
                realtime.hasSessionExpiredError || !session.isAuthenticated
                ? () => Navigator.pushNamed(context, AppRoutes.devices)
                : realtime.hasPermissionError
                ? () => Navigator.pushNamed(context, AppRoutes.devices)
                : null,
          ),
        if (ecg.message != null && ecg.message!.trim().isNotEmpty)
          _InfoBanner(message: ecg.message!),
        if (!hasLatest && realtime.isLoadingLatest) const _LoadingPanel(),
        if (!hasLatest && realtime.latestStatus.isEmpty)
          _EmptyPanel(
            message: _noDataMessage(
              realtime: realtime,
              session: session,
            ),
          ),
        FeatureButton(
          icon: Icons.history,
          title: 'Lịch sử',
          subtitle: 'Xem lịch sử theo ngày',
          onTap: () => Navigator.pushNamed(context, AppRoutes.history),
        ),
        FeatureButton(
          icon: Icons.notifications_active_outlined,
          title: 'Cảnh báo',
          subtitle: 'Xem cảnh báo và mở đúng thiết bị',
          onTap: _openAlerts,
        ),
      ];

      final secondaryChildren = <Widget>[
        if (!currentDevice.isOwnerLink)
          const _InfoBanner(
            message:
                'Bạn đang ở chế độ chỉ xem trên thiết bị này. Chỉ chủ thiết bị mới có thể quản lý người xem và gửi yêu cầu đo ECG.',
          ),
        if (currentDevice.isOwnerLink)
          _EcgActionCard(
            enabled: currentDevice.hasExplicitDeviceId && !ecg.isLoading,
            isLoading: ecg.isLoading,
            onTap: () => _requestEcg(currentDevice),
          ),
        if (currentDevice.isOwnerLink)
          FeatureButton(
            icon: Icons.group_outlined,
            title: 'Quản lý người xem',
            subtitle: 'Thêm hoặc xóa tài khoản được xem thiết bị này',
            onTap: () => _openOwnerManagement(currentDevice),
          ),
        FeatureButton(
          icon: Icons.devices,
          title: currentDevice.isOwnerLink
              ? 'Quản lý thiết bị'
              : 'Thông tin thiết bị',
          subtitle: currentDevice.isOwnerLink
              ? 'Xem danh sách thiết bị và quyền chia sẻ'
              : 'Xem thiết bị đang được chia sẻ cho bạn',
          onTap: () => Navigator.pushNamed(context, AppRoutes.devices),
        ),
      ];

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding,
        children: [
          _DeviceSelectorCard(
            devices: devices,
            currentDeviceId: currentDevice.id,
            isSyncing: deviceProvider.isSyncing,
            onChanged: _selectDevice,
            onOpenList: () => Navigator.pushNamed(context, AppRoutes.devices),
          ),
          SizedBox(height: sectionSpacing),
          ResponsiveTwoPane(
            breakpoint: 1080,
            spacing: sectionSpacing,
            primary: _SectionColumn(
              spacing: sectionSpacing,
              children: primaryChildren,
            ),
            secondary: _SectionColumn(
              spacing: sectionSpacing,
              children: secondaryChildren,
            ),
          ),
        ],
      );
    }

    Widget buildNoDeviceContent() {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildNoDeviceView(context),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Eldercare'),
        centerTitle: !isExpanded,
        actions: [
          IconButton(
            tooltip: 'Cảnh báo',
            onPressed: _openAlerts,
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Đổi thiết bị',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
            icon: const Icon(Icons.devices),
          ),
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            onPressed: realtime.isLoadingLatest ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isCompact ? 46 : 50),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              isCompact ? 10 : 12,
            ),
            child: Align(
              alignment: isExpanded
                  ? Alignment.centerLeft
                  : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
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
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: device == null ? buildNoDeviceContent() : buildDeviceContent(),
          ),
        ),
      ),
    );
  }

  String _noDataMessage({
    required RealtimeProvider realtime,
    required SessionProvider session,
  }) {
    if (!session.isAuthenticated) {
      return 'Bạn chưa đăng nhập. Vào mục Thiết bị để đăng nhập và đồng bộ phiên làm việc.';
    }
    if (realtime.hasPermissionError) {
      return 'Tài khoản hiện tại không có quyền xem thiết bị này.';
    }
    if (realtime.hasNoDataError) {
      return 'Thiết bị đã được liên kết nhưng chưa có bản ghi nào trên máy chủ.';
    }
    return 'Thiết bị đã được chọn nhưng chưa có dữ liệu mới nhất. Hãy thử làm mới lại sau khi thiết bị gửi dữ liệu.';
  }

  Widget _buildNoDeviceView(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final scheme = Theme.of(context).colorScheme;
    final title = session.isAuthenticated
        ? 'Bạn chưa có thiết bị nào'
        : 'Chưa đăng nhập';
    final message = session.isAuthenticated
        ? 'Bạn có thể thêm thiết bị bằng mã thiết bị để liên kết thiết bị.\nNếu bạn là người xem, vui lòng liên hệ chủ thiết bị để được cấp quyền xem.'
        : 'Bạn cần đăng nhập trước, sau đó ứng dụng sẽ tải danh sách thiết bị đã liên kết từ máy chủ.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other, size: 64, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.devices),
                icon: Icon(
                  session.isAuthenticated
                      ? Icons.settings_input_antenna
                      : Icons.login,
                ),
                label: Text(
                  session.isAuthenticated
                      ? 'Mở danh sách thiết bị'
                      : 'Đăng nhập',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({
    required this.children,
    required this.spacing,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withSpacing(visibleChildren, spacing),
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
    final layout = AppLayout.of(context);
    final isCompact = layout == AppLayoutSize.compact;

    Device? current;
    for (final device in devices) {
      if (device.id == currentDeviceId) {
        current = device;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thiết bị đang theo dõi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: isCompact ? 10 : 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  devices.any((device) => device.id == currentDeviceId)
                  ? currentDeviceId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Chọn thiết bị',
                prefixIcon: Icon(Icons.devices),
              ),
              items: devices
                  .map(
                    (device) => DropdownMenuItem<String>(
                      value: device.id,
                      child: Text('${device.name} (${device.resolvedDeviceId})'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: devices.length <= 1 ? null : onChanged,
            ),
            SizedBox(height: isCompact ? 10 : 8),
            Text(
              current == null
                  ? 'Chưa có thiết bị hiện tại.'
                  : 'Quyền trên thiết bị hiện tại: ${deviceAccessRoleLabel(current.normalizedLinkRole)} | Tài khoản liên kết: ${current.linkedUsers.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: isCompact ? 10 : 8),
            if (isCompact)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onOpenList,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Mở danh sách thiết bị'),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpenList,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Mở danh sách thiết bị'),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackAction =
            constraints.maxWidth < 360 &&
            actionLabel != null &&
            onAction != null;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: stackAction
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: scheme.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                )
              : Row(
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
      },
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
            Text('Đang tải dữ liệu mới nhất...'),
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
    final isCompact = AppLayout.isCompact(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đo ECG theo yêu cầu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? 'Gửi lệnh đo ECG cho thiết bị đang theo dõi.'
                  : 'Không thể gửi lệnh đo ECG cho thiết bị này.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? onTap : null,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_outline),
                label: Text(
                  isLoading ? 'Đang gửi yêu cầu...' : 'Yêu cầu đo ECG',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, double spacing) {
  final spacedChildren = <Widget>[];

  for (final child in children) {
    if (spacedChildren.isNotEmpty) {
      spacedChildren.add(SizedBox(height: spacing));
    }
    spacedChildren.add(child);
  }

  return spacedChildren;
}
