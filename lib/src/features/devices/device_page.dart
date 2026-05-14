import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/claim_device_page.dart';
import 'package:eldercare_app/src/features/devices/device_thresholds_page.dart';
import 'package:eldercare_app/src/features/devices/device_viewers_page.dart';
import 'package:eldercare_app/src/features/navigation/main_shell.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/device_card.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/section_header.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final session = context.read<SessionProvider>();
    if (!session.isAuthenticated) return;
    await context.read<DeviceProvider>().syncFromServer(
      authenticatedUserId: session.authenticatedUserId,
    );
  }

  Future<void> _selectDevice(Device device) async {
    final deviceProvider = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();
    await deviceProvider.setCurrent(device.id);
    await realtime.changeDevice(device.resolvedDeviceId);
    if (!mounted) return;
    MainShell.maybeOf(context)?.goToTab(MainTab.home);
  }

  Future<void> _openClaimDevice() async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ClaimDevicePage()),
    );
    if (!mounted || result == null) return;
    if (session.isAuthenticated) {
      await deviceProvider.syncFromServer(
        authenticatedUserId: session.authenticatedUserId,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liên kết thiết bị thành công.')),
    );
  }

  Future<void> _openManageSheet(Device device, bool isAdmin) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                device.resolvedDeviceId,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Đổi tên hiển thị'),
                onTap: () async {
                  Navigator.pop(context);
                  await _renameDevice(device);
                },
              ),
              if (device.isOwnerLink)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Quản lý người xem'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceViewersPage(device: device),
                      ),
                    );
                    await _refresh();
                  },
                ),
              if (device.isOwnerLink)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Cập nhật ngưỡng cảnh báo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceThresholdsPage(),
                      ),
                    );
                  },
                ),
              if (isAdmin)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Đăng ký thiết bị mới'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.adminDeviceRegister);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameDevice(Device device) async {
    final controller = TextEditingController(text: device.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên thiết bị'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên hiển thị',
            hintText: 'Ví dụ: Elder Band phòng ngủ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted || result == null || result.trim().isEmpty) return;
    await context.read<DeviceProvider>().rename(device.id, result.trim());
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final realtime = context.watch<RealtimeProvider>();
    final isAdmin = session.authenticatedRole == 'admin';
    final currentDevice = deviceProvider.current;
    final visibleDevices = deviceProvider.devices.where((device) {
      if (_query.isEmpty) return true;
      final haystack = <String>[
        device.name.toLowerCase(),
        device.resolvedDeviceId.toLowerCase(),
        ...device.linkedUsers.map((user) => user.displayName.toLowerCase()),
      ];
      return haystack.any((value) => value.contains(_query));
    }).toList(growable: false);

    final otherDevices = visibleDevices
        .where((device) => device.id != currentDevice?.id)
        .toList(growable: false);

    return AppScaffold(
      title: 'Thiết bị',
      subtitle: 'Quản lý danh sách thiết bị đã liên kết và quyền truy cập.',
      actions: [
        if (isAdmin)
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.adminDeviceRegister),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        IconButton(
          onPressed: deviceProvider.isSyncing ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppCard(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tìm thiết bị...',
                  labelText: 'Tìm thiết bị',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            if (deviceProvider.devices.isEmpty)
              EmptyState(
                icon: Icons.watch_off_outlined,
                title: 'Bạn chưa liên kết thiết bị nào',
                message:
                    'Liên kết thiết bị bằng Device ID và Pairing Code để bắt đầu theo dõi.',
                actionLabel: 'Liên kết thiết bị',
                onAction: _openClaimDevice,
              )
            else ...[
              SectionHeader(
                title: 'Thiết bị đang theo dõi',
                subtitle: currentDevice == null
                    ? 'Chưa chọn thiết bị hiện tại.'
                    : 'Thiết bị chính đang dùng để theo dõi sức khỏe.',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (currentDevice != null)
                AppDeviceCard(
                  device: currentDevice,
                  isCurrent: true,
                  isOnline: realtime.hasDevice ? realtime.isOnline : null,
                  onTrack: () => _selectDevice(currentDevice),
                  onManage: () => _openManageSheet(currentDevice, isAdmin),
                ),
              const SizedBox(height: AppSpacing.section),
              Row(
                children: [
                  Expanded(
                    child: SectionHeader(
                      title: 'Danh sách thiết bị',
                      subtitle: otherDevices.isEmpty
                          ? 'Không còn thiết bị nào khác.'
                          : 'Chuyển nhanh thiết bị đang theo dõi hoặc mở quản lý.',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openClaimDevice,
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Liên kết thiết bị'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (otherDevices.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Không có thiết bị phù hợp',
                  message: 'Thử thay đổi từ khoá tìm kiếm hoặc làm mới dữ liệu.',
                )
              else
                ...otherDevices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: AppDeviceCard(
                      device: device,
                      isCurrent: false,
                      isOnline: null,
                      onTrack: () => _selectDevice(device),
                      onManage: () => _openManageSheet(device, isAdmin),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
