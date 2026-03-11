import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/device_qr_scanner_page.dart';
import 'package:eldercare_app/src/features/home/home_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _lastBoundUserId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _syncRealtimeWithCurrent() {
    final device = context.read<DeviceProvider>().current;
    final rt = context.read<RealtimeProvider>();
    final userId = device?.id ?? '';
    final deviceId = device?.resolvedDeviceId ?? '';

    if (_lastBoundUserId == userId) return;
    _lastBoundUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await rt.init(userId: userId, deviceId: deviceId);
    });
  }

  /// ---------------------- MENU (☰) ----------------------

  void _openMenu(BuildContext context) {
    final current = context.read<DeviceProvider>().current;
    final rt = context.read<RealtimeProvider>();
    final watchingText = current == null
        ? 'Chưa theo dõi thiết bị'
        : 'Đang theo dõi: ${_displayName(current)}';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final t = Theme.of(ctx).textTheme;

        return LayoutBuilder(
          builder: (ctx, constraints) {
            // Giới hạn chiều cao sheet để không overflow
            final maxH = (constraints.maxHeight * 0.88).clamp(320.0, 760.0);

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
                child: Material(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    child: Column(
                      children: [
                        const _SheetHandle(),
                        const SizedBox(height: 10),

                        // Header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.menu_rounded,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Menu',
                                    style: t.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    watchingText,
                                    style: t.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (current != null)
                                    _MiniStatusPill(
                                      isOnline: rt.isOnline,
                                      text: rt.lastSeenText,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Đóng',
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ✅ Quan trọng: phần dưới cho cuộn để không overflow
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                _MenuSection(
                                  title: 'Hệ thống',
                                  children: [
                                    _MenuItem(
                                      icon: Icons.dark_mode_outlined,
                                      title: 'Giao diện',
                                      subtitle: 'Sáng / Tối / Theo hệ thống',
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showThemeDialog(context);
                                      },
                                      trailing: Icons.chevron_right_rounded,
                                    ),
                                    _MenuItem(
                                      icon: Icons.wifi_tethering_outlined,
                                      title: 'Kiểm tra kết nối',
                                      subtitle: 'API server',
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _showConnectionCheck(context);
                                      },
                                      trailing: Icons.chevron_right_rounded,
                                    ),
                                    _MenuItem(
                                      icon: Icons.refresh_rounded,
                                      title: 'Làm mới & Kết nối lại',
                                      subtitle: 'Refresh du lieu REST',
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final rt = context
                                            .read<RealtimeProvider>();
                                        if (rt.hasUser) {
                                          await rt.refreshLatest();
                                          await rt.reconnectApi();
                                        }
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Đã làm mới & kết nối lại',
                                            ),
                                          ),
                                        );
                                      },
                                      trailing: Icons.chevron_right_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _MenuSection(
                                  title: 'Trợ giúp',
                                  children: [
                                    _MenuItem(
                                      icon: Icons.help_outline_rounded,
                                      title: 'Hướng dẫn sử dụng',
                                      subtitle:
                                          'Quét QR • Gắn điện cực ECG • Xem History',
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showHelp(context);
                                      },
                                      trailing: Icons.chevron_right_rounded,
                                    ),
                                    _MenuItem(
                                      icon: Icons.info_outline_rounded,
                                      title: 'Thông tin ứng dụng',
                                      subtitle: 'Phiên bản • tác giả',
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showAbout(context);
                                      },
                                      trailing: Icons.chevron_right_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giao diện'),
        content: const Text(
          'Hiện tại app đang dùng ThemeMode.light.\n'
          'Nếu muốn đổi nhanh Sáng/Tối trong app, mình có thể làm thêm SettingsProvider để lưu setting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConnectionCheck(BuildContext context) async {
    final rt = context.read<RealtimeProvider>();

    String result;
    try {
      final serverOk = await rt.checkServer();
      if (!serverOk) {
        result = 'Khong the ket noi server. Kiem tra API_BASE_URL va mang.';
      } else if (!rt.isAuthenticated) {
        final loggedIn = await rt.ensureAuthenticated(silent: false);
        if (!loggedIn) {
          result =
              rt.error ??
              'Server OK nhung khong dang nhap duoc. Kiem tra LOGIN_USER_ID va LOGIN_PASSWORD.';
        } else if (!rt.hasUser) {
          result =
              'Dang nhap thanh cong nhung chua chon user/device de kiem tra du lieu.';
        } else {
          await rt.refreshLatest();
          await rt.reconnectApi();
          result = 'Dang nhap va ket noi server thanh cong. Da refresh latest.';
        }
      } else if (!rt.hasUser) {
        result = 'Server OK, nhung chua chon user/device de kiem tra du lieu.';
      } else {
        await rt.refreshLatest();
        await rt.reconnectApi();
        result = 'Dang nhap va ket noi server thanh cong. Da refresh latest.';
      }
    } catch (e) {
      result = 'Loi kiem tra ket noi: $e';
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kiểm tra kết nối'),
        content: Text(result),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hướng dẫn nhanh'),
        content: const Text(
          '• Thêm thiết bị: nhấn “Quét QR” hoặc “Nhập userId”.\n'
          '• Chọn thiết bị: nhấn vào thẻ thiết bị để xem chỉ số.\n'
          '• ECG: nếu báo “Chưa gắn điện cực” thì kiểm tra dây/miếng dán.\n'
          '• History: xem theo ngày/giờ trong mục History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Eldercare',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.health_and_safety_rounded),
      children: const [
        SizedBox(height: 8),
        Text('Ứng dụng theo dõi chỉ số sức khỏe & ECG (AD8232).'),
      ],
    );
  }

  /// ---------------------- LOGIC THIẾT BỊ ----------------------

  Future<bool> _ensureAuthenticated(BuildContext context) async {
    final realtime = context.read<RealtimeProvider>();
    final ok = await realtime.ensureAuthenticated(silent: false);
    if (!context.mounted) return false;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            realtime.error ??
                'Khong the dang nhap vao server. Kiem tra LOGIN_USER_ID va LOGIN_PASSWORD.',
          ),
        ),
      );
    }
    return ok;
  }

  Future<void> _scanAndAdd(BuildContext context) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DeviceQrScannerPage()),
    );
    if (code == null || code.trim().isEmpty) return;
    if (!context.mounted) return;

    final ok = await _ensureAuthenticated(context);
    if (!ok) return;
    if (!context.mounted) return;

    final deviceProv = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();

    await deviceProv.addFromQr(code);

    final current = deviceProv.current;
    if (current != null) {
      await realtime.changeUser(current.id, deviceId: current.resolvedDeviceId);
    }
  }

  Future<void> _showManualAddDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final userIdController = TextEditingController();
    final nameController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Thêm thiết bị'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userIdController,
                  decoration: const InputDecoration(
                    labelText: 'userId',
                    hintText: 'VD: u01',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nhập userId';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên thiết bị (tuỳ chọn)',
                    hintText: 'VD: Thiết bị phòng ngủ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!context.mounted) return;

    final userId = userIdController.text.trim();
    final name = nameController.text.trim();
    if (userId.isEmpty) return;

    final authenticated = await _ensureAuthenticated(context);
    if (!authenticated) return;
    if (!context.mounted) return;

    final deviceProv = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();

    await deviceProv.addFromQr(userId);

    if (name.isNotEmpty) {
      await deviceProv.rename(userId, name);
    }

    await realtime.changeUser(userId, deviceId: userId);
  }

  Future<void> _renameDialog(
    BuildContext context,
    String id,
    String oldName,
  ) async {
    final ctrl = TextEditingController(text: oldName);
    final provider = context.read<DeviceProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa tên thiết bị'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên hiển thị'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await provider.rename(id, ctrl.text);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final provider = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thiết bị?'),
        content: const Text(
          'Thiết bị sẽ bị xóa khỏi danh sách trên app (không ảnh hưởng ESP).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await provider.remove(id);

      final devices = provider.devices;
      if (devices.isEmpty) {
        await realtime.changeUser('', deviceId: '');
      } else {
        final current = provider.current;
        if (current == null) {
          final d0 = devices.first;
          await provider.setCurrent(d0.id);
          await realtime.changeUser(d0.id, deviceId: d0.resolvedDeviceId);
        }
      }
    }
  }

  String _displayName(Device d) {
    final n = d.name.trim();
    if (n.isNotEmpty) return n;
    return 'Thiết bị ${d.id}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final rt = context.watch<RealtimeProvider>();
    context.watch<DeviceProvider>().current;
    _syncRealtimeWithCurrent();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 92,
        title: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LogoCircle(color: scheme.primary),
                  const SizedBox(width: 10),
                  const Text('Danh sách thiết bị'),
                ],
              ),
              const SizedBox(height: 6),
              Consumer<DeviceProvider>(
                builder: (context, p, child) =>
                    _CountChip(text: '${p.devices.length} thiết bị'),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chưa có thông báo')),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Menu',
            onPressed: () => _openMenu(context),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'manualAddDevice',
            onPressed: () => _showManualAddDialog(context),
            icon: const Icon(Icons.edit),
            label: const Text('Nhập userId'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scanAddDevice',
            onPressed: () => _scanAndAdd(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Quét QR'),
          ),
        ],
      ),

      body: SafeArea(
        child: Consumer<DeviceProvider>(
          builder: (context, p, _) {
            final devices = p.devices;
            final current = p.current;

            final filtered = _query.isEmpty
                ? devices
                : devices.where((d) {
                    final name = d.name.toLowerCase();
                    final id = d.id.toLowerCase();
                    return name.contains(_query) || id.contains(_query);
                  }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
              children: [
                _SummaryCard(
                  total: devices.length,
                  watchingName: current == null ? null : _displayName(current),
                ),
                const SizedBox(height: 12),

                _SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Tìm thiết bị...',
                  onClear: () => _searchCtrl.clear(),
                ),
                const SizedBox(height: 12),

                if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'Chưa có thiết bị nào.\nNhấn “Quét QR” hoặc “Nhập userId” để thêm.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'Không tìm thấy thiết bị phù hợp.',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...List.generate(filtered.length, (index) {
                    final d = filtered[index];
                    final isCurrent = current?.id == d.id;

                    final chip = isCurrent
                        ? _StatusChip(
                            isOnline: rt.isOnline,
                            text: rt.lastSeenText,
                          )
                        : const _NeutralChip(text: 'Chưa theo dõi');

                    final initial =
                        (_displayName(d).isNotEmpty
                                ? _displayName(d)[0]
                                : (d.id.isNotEmpty ? d.id[0] : '?'))
                            .toUpperCase();

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == filtered.length - 1 ? 0 : 12,
                      ),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: scheme.primaryContainer,
                                foregroundColor: scheme.onPrimaryContainer,
                                child: Text(initial),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final deviceProv = context
                                        .read<DeviceProvider>();
                                    final realtime = context
                                        .read<RealtimeProvider>();

                                    await deviceProv.setCurrent(d.id);
                                    await realtime.changeUser(
                                      d.id,
                                      deviceId: d.resolvedDeviceId,
                                    );

                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const HomePage(),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName(d),
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Nhấn để xem chỉ số',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          chip,
                                          const SizedBox(width: 10),
                                          if (isCurrent) const _WatchingChip(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  _ActionPill(
                                    icon: Icons.edit,
                                    label: 'Sửa tên',
                                    onTap: () =>
                                        _renameDialog(context, d.id, d.name),
                                  ),
                                  const SizedBox(height: 10),
                                  _ActionPill(
                                    icon: Icons.delete_outline,
                                    label: 'Xóa',
                                    isDanger: true,
                                    onTap: () => _confirmDelete(context, d.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ---------------- UI widgets ----------------

class _LogoCircle extends StatelessWidget {
  const _LogoCircle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: const Icon(
        Icons.health_and_safety_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, this.watchingName});
  final int total;
  final String? watchingName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.desktop_windows_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng: $total thiết bị',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    watchingName == null
                        ? 'Chưa theo dõi thiết bị nào'
                        : 'Đang theo dõi: $watchingName',
                    style: t.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hintText,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              tooltip: 'Xóa',
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            onPressed: () {},
            tooltip: 'Sắp xếp',
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOnline, required this.text});
  final bool isOnline;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = isOnline ? scheme.primaryContainer : scheme.errorContainer;
    final fg = isOnline ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: isOnline ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? 'Online · cập nhật $text' : 'Offline · $text',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralChip extends StatelessWidget {
  const _NeutralChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WatchingChip extends StatelessWidget {
  const _WatchingChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            'Đang theo dõi',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = isDanger
        ? scheme.errorContainer.withValues(alpha: 0.35)
        : scheme.surfaceContainerHighest;
    final fg = isDanger ? scheme.error : scheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------- MENU UI helpers (đẹp hơn) ----------------

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      height: 5,
      decoration: BoxDecoration(
        color: scheme.outlineVariant.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ..._withDividers(children, scheme),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items, ColorScheme scheme) {
    final out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(left: 54, right: 6),
            child: Divider(
              height: 14,
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
        );
      }
    }
    return out;
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surfaceContainerHighest;
    final fg = scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(trailing, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.isOnline, required this.text});

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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
