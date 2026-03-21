import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/core/app_date_utils.dart';
import 'package:eldercare_app/src/core/app_layout.dart';
import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/claim_device_page.dart';
import 'package:eldercare_app/src/features/devices/device_viewers_page.dart';
import 'package:eldercare_app/src/features/home/home_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/app_logo.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _searchCtrl = TextEditingController();
  final _loginPhoneCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  String _query = '';
  String? _lastRealtimeBindingKey;
  String? _lastSessionMessage;
  DeviceProvider? _deviceProvider;

  @override
  void initState() {
    super.initState();
    _loginPhoneCtrl.text = Env.debugLoginPhoneNumber;
    _loginPasswordCtrl.text = Env.debugLoginPassword;
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextDeviceProvider = context.read<DeviceProvider>();
    if (identical(_deviceProvider, nextDeviceProvider)) return;

    _deviceProvider?.removeListener(_handleDeviceProviderChanged);
    _deviceProvider = nextDeviceProvider;
    _deviceProvider?.addListener(_handleDeviceProviderChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleDeviceProviderChanged();
    });
  }

  @override
  void dispose() {
    _deviceProvider?.removeListener(_handleDeviceProviderChanged);
    _searchCtrl.dispose();
    _loginPhoneCtrl.dispose();
    _loginPasswordCtrl.dispose();
    super.dispose();
  }

  void _handleDeviceProviderChanged() {
    _bindCurrentDeviceToRealtime();
  }

  void _bindCurrentDeviceToRealtime() {
    final realtime = context.read<RealtimeProvider>();
    final session = context.read<SessionProvider>();
    final current = context.read<DeviceProvider>().current;
    final deviceId = current?.resolvedDeviceId ?? '';
    final bindingKey = '${session.authenticatedUserId}::$deviceId';

    if (_lastRealtimeBindingKey == bindingKey) return;
    _lastRealtimeBindingKey = bindingKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await realtime.init(deviceId: deviceId);
    });
  }

  Future<void> _login() async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final ok = await session.login(
      phoneNumber: AppValidators.normalizePhoneNumber(_loginPhoneCtrl.text),
      password: _loginPasswordCtrl.text,
    );
    if (!mounted || !ok) return;

    await deviceProvider.handleSessionState(
      isAuthenticated: session.isAuthenticated,
      authenticatedUserId: session.authenticatedUserId,
    );
  }

  void _handleSessionFeedback(SessionProvider session) {
    final nextMessage = session.error?.trim();
    final shouldShowSessionExpired =
        !session.isAuthenticated &&
        session.lastErrorStatusCode == 401 &&
        nextMessage != null &&
        nextMessage.isNotEmpty &&
        nextMessage == AppStrings.sessionExpired &&
        _lastSessionMessage != nextMessage;

    _lastSessionMessage = nextMessage;
    if (!shouldShowSessionExpired) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.sessionExpired)),
        );
    });
  }

  Future<void> _openRegister() async {
    final result = await Navigator.pushNamed(context, AppRoutes.register);
    if (result is! String || result.trim().isEmpty || !mounted) return;

    _loginPhoneCtrl.text = result.trim();
    _loginPasswordCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tạo tài khoản thành công. Vui lòng đăng nhập.'),
      ),
    );
  }

  Future<void> _refreshDevices() async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    if (session.isAuthenticated) {
      await deviceProvider.syncFromServer(
        authenticatedUserId: session.authenticatedUserId,
      );
      return;
    }
  }

  Future<void> _openClaimDevice() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute<String?>(builder: (_) => const ClaimDevicePage()),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liên kết thiết bị thành công.')),
    );
  }

  Future<void> _logout() async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    await session.logout();
    await deviceProvider.clear();

    _lastRealtimeBindingKey = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đăng xuất phiên hiện tại.')),
    );
  }

  Future<void> _selectDevice(Device device) async {
    final deviceProvider = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();

    await deviceProvider.setCurrent(device.id);
    await realtime.changeDevice(device.resolvedDeviceId);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _handleLinkDevice() async {
    await _openClaimDevice();
  }

  Future<void> _renameDevice(Device device) async {
    final renamed = await _showRenameDeviceDialog(
      context,
      initialName: device.name,
    );
    if (!mounted || renamed == null) return;

    final nextName = renamed.trim();
    if (nextName.isEmpty || nextName == device.name.trim()) return;

    await context.read<DeviceProvider>().rename(device.id, nextName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã đổi tên thiết bị thành "$nextName".')),
    );
  }

  Future<void> _openAdminDeviceRegistration() async {
    await Navigator.pushNamed(context, AppRoutes.adminDeviceRegister);
  }

  Future<void> _openAccountPage() async {
    await Navigator.pushNamed(context, AppRoutes.account);
  }

  Future<void> _showLinkGuideDialog() async {
    const content =
        'Nếu bạn là chủ thiết bị, hãy dùng chức năng thêm thiết bị bằng mã thiết bị để liên kết thiết bị.\n\n'
        'Nếu bạn chỉ cần quyền xem, vui lòng liên hệ chủ thiết bị để được thêm vào danh sách người xem.';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hướng dẫn liên kết thiết bị'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final realtime = context.watch<RealtimeProvider>();
    final isAdmin = session.authenticatedRole == 'admin';
    _handleSessionFeedback(session);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.isAuthenticated ? 'Thiết bị đã liên kết' : 'Đăng nhập',
        ),
        actions: [
          if (session.isAuthenticated)
            IconButton(
              tooltip: 'Liên kết thiết bị',
              onPressed: _openClaimDevice,
              icon: const Icon(Icons.add_link),
            ),
          if (session.isAuthenticated && isAdmin)
            IconButton(
              tooltip: 'Đăng ký thiết bị',
              onPressed: _openAdminDeviceRegistration,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (session.isAuthenticated)
            IconButton(
              tooltip: 'Tài khoản',
              onPressed: _openAccountPage,
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refreshDevices,
            icon: const Icon(Icons.refresh),
          ),
          if (session.isAuthenticated)
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: session.isAuthenticated
          ? _AuthenticatedBody(
              query: _query,
              searchCtrl: _searchCtrl,
              deviceProvider: deviceProvider,
              session: session,
              realtime: realtime,
              onRefresh: _refreshDevices,
              onSelectDevice: _selectDevice,
              onLinkDevice: () {
                _handleLinkDevice();
              },
              onShowLinkGuide: () {
                _showLinkGuideDialog();
              },
              onRenameDevice: _renameDevice,
              isAdmin: isAdmin,
              onOpenAdminRegistration: _openAdminDeviceRegistration,
              onOpenAccountPage: _openAccountPage,
            )
          : _LoginBody(
              phoneCtrl: _loginPhoneCtrl,
              passwordCtrl: _loginPasswordCtrl,
              isAuthenticating: session.isAuthenticating,
              errorMessage: session.error,
              onLogin: () {
                _login();
              },
              onRegister: () {
                _openRegister();
              },
            ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.isAuthenticating,
    required this.errorMessage,
    required this.onLogin,
    required this.onRegister,
  });

  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final bool isAuthenticating;
  final String? errorMessage;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final isCompact = layout == AppLayoutSize.compact;
    final maxWidth = layout == AppLayoutSize.expanded ? 560.0 : 460.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            shrinkWrap: true,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 16 : 20),
                  child: _LoginFormContent(
                    phoneCtrl: phoneCtrl,
                    passwordCtrl: passwordCtrl,
                    isAuthenticating: isAuthenticating,
                    errorMessage: errorMessage,
                    onLogin: onLogin,
                    onRegister: onRegister,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedBody extends StatelessWidget {
  const _AuthenticatedBody({
    required this.query,
    required this.searchCtrl,
    required this.deviceProvider,
    required this.session,
    required this.realtime,
    required this.onRefresh,
    required this.onSelectDevice,
    required this.onLinkDevice,
    required this.onShowLinkGuide,
    required this.onRenameDevice,
    required this.isAdmin,
    required this.onOpenAdminRegistration,
    required this.onOpenAccountPage,
  });

  final String query;
  final TextEditingController searchCtrl;
  final DeviceProvider deviceProvider;
  final SessionProvider session;
  final RealtimeProvider realtime;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Device device) onSelectDevice;
  final VoidCallback onLinkDevice;
  final VoidCallback onShowLinkGuide;
  final Future<void> Function(Device device) onRenameDevice;
  final bool isAdmin;
  final VoidCallback onOpenAdminRegistration;
  final VoidCallback onOpenAccountPage;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final contentMaxWidth = AppLayout.maxContentWidth(context);
    final pagePadding = AppLayout.pagePadding(
      context,
      compact: 12,
      medium: 20,
      expanded: 24,
      bottom: layout == AppLayoutSize.expanded ? 28 : 24,
    );
    final devices = deviceProvider.devices
        .where((device) {
          if (query.isEmpty) return true;

          final haystacks = <String>[
            device.name.toLowerCase(),
            device.resolvedDeviceId.toLowerCase(),
            ...device.linkedUsers.map((user) => user.displayName.toLowerCase()),
            ...device.linkedUsers
                .map((user) => user.phoneNumber?.toLowerCase())
                .whereType<String>(),
          ];
          return haystacks.any((entry) => entry.contains(query));
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: pagePadding,
            children: [
              _SessionCard(
                name: session.currentUser?.name ?? '',
                userId: session.currentUser?.userId ?? '',
                phoneNumber: session.currentUser?.phoneNumber ?? '',
                dateOfBirth: session.currentUser?.dateOfBirth,
                totalDevices: deviceProvider.devices.length,
                currentDevice: deviceProvider.current,
                onOpenAccountPage: onOpenAccountPage,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                _AdminDeviceRegistrationCard(onOpen: onOpenAdminRegistration),
              ],
              if (realtime.error != null &&
                  realtime.error!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _InlineBanner(
                  color: Theme.of(context).colorScheme.errorContainer,
                  textColor: Theme.of(context).colorScheme.onErrorContainer,
                  message: realtime.error!,
                ),
              ],
              if (deviceProvider.error != null &&
                  deviceProvider.error!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _InlineBanner(
                  color: Theme.of(context).colorScheme.errorContainer,
                  textColor: Theme.of(context).colorScheme.onErrorContainer,
                  message: deviceProvider.error!,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText:
                      'Tìm theo tên thiết bị, mã thiết bị, tài khoản liên kết...',
                ),
              ),
              const SizedBox(height: 16),
              if (deviceProvider.isSyncing && deviceProvider.devices.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (devices.isEmpty)
                _EmptyState(
                  title: deviceProvider.devices.isEmpty
                      ? 'Bạn chưa có thiết bị nào'
                      : 'Không có thiết bị phù hợp',
                  message: deviceProvider.devices.isEmpty
                      ? 'Bạn có thể thêm thiết bị bằng mã thiết bị để liên kết thiết bị. Nếu bạn chỉ cần quyền xem, vui lòng liên hệ chủ thiết bị để được cấp quyền người xem.'
                      : 'Hãy thử đổi bộ lọc tìm kiếm hoặc làm mới danh sách thiết bị.',
                  actionLabel: deviceProvider.devices.isEmpty
                      ? 'Liên kết thiết bị'
                      : null,
                  onAction: deviceProvider.devices.isEmpty
                      ? onLinkDevice
                      : null,
                  secondaryActionLabel: deviceProvider.devices.isEmpty
                      ? AppStrings.noLinkedDeviceGuide
                      : null,
                  onSecondaryAction: deviceProvider.devices.isEmpty
                      ? onShowLinkGuide
                      : null,
                )
              else
                ...devices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DeviceCard(
                      device: device,
                      isCurrent: deviceProvider.current?.id == device.id,
                      onManageViewers: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceViewersPage(device: device),
                          ),
                        );
                        await onRefresh();
                      },
                      onRename: () => onRenameDevice(device),
                      onSelect: () => onSelectDevice(device),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.name,
    required this.userId,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.totalDevices,
    required this.currentDevice,
    required this.onOpenAccountPage,
  });

  final String name;
  final String userId;
  final String phoneNumber;
  final String? dateOfBirth;
  final int totalDevices;
  final Device? currentDevice;
  final VoidCallback onOpenAccountPage;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin tài khoản',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Tên: ${name.trim().isEmpty ? 'Chưa cập nhật' : name}'),
            Text(
              'Mã tài khoản: ${userId.trim().isEmpty ? 'Chưa cập nhật' : userId}',
            ),
            Text(
              'SĐT: ${phoneNumber.trim().isEmpty ? 'Chưa cập nhật' : phoneNumber}',
            ),
            Text(
              'Ngày sinh: ${_formatDateOfBirth(dateOfBirth) ?? 'Chưa cập nhật'}',
            ),
            Text(
              currentDevice == null
                  ? 'Quyền trên thiết bị hiện tại: Chưa chọn thiết bị'
                  : 'Quyền trên thiết bị hiện tại: ${deviceAccessRoleLabel(currentDevice!.normalizedLinkRole)}',
            ),
            Text('Số thiết bị đã liên kết: $totalDevices'),
            const SizedBox(height: 8),
            Text(
              currentDevice == null
                  ? 'Chưa chọn thiết bị nào.'
                  : 'Đang theo dõi: ${currentDevice!.name} (${currentDevice!.resolvedDeviceId})',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenAccountPage,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Mở trang tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDeviceRegistrationCard extends StatelessWidget {
  const _AdminDeviceRegistrationCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 560;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Công cụ quản trị thiết bị',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Tạo mới thiết bị hoặc cấp lại mã ghép nối để chuyển cho chủ thiết bị liên kết trên ứng dụng.',
        ),
      ],
    );
    final button = FilledButton.icon(
      onPressed: onOpen,
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('Đăng ký thiết bị'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined),
                  const SizedBox(height: 12),
                  info,
                  const SizedBox(height: 12),
                  button,
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.isCurrent,
    required this.onManageViewers,
    required this.onRename,
    required this.onSelect,
  });

  final Device device;
  final bool isCurrent;
  final Future<void> Function() onManageViewers;
  final Future<void> Function() onRename;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final theme = Theme.of(context);
    final viewers = device.linkedUsers
        .where((user) => user.isViewerLink)
        .toList(growable: false);
    final roleLabel = deviceAccessRoleLabel(device.normalizedLinkRole);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    device.name.trim().isEmpty
                        ? '?'
                        : device.name.trim()[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Mã thiết bị: ${device.resolvedDeviceId}'),
                      const SizedBox(height: 6),
                      Chip(label: Text('Quyền trên thiết bị này: $roleLabel')),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đổi tên trên ứng dụng',
                  onPressed: () {
                    onRename();
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                if (isCurrent)
                  Chip(
                    avatar: const Icon(Icons.check, size: 18),
                    label: const Text('Đang theo dõi'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (device.isOwnerLink) ...[
              Text(
                'Người xem đang được chia sẻ',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (viewers.isEmpty)
                Text(
                  'Chưa có người xem nào được thêm vào thiết bị này.',
                  style: theme.textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: viewers
                      .map((user) => Chip(label: Text(_linkedUserLabel(user))))
                      .toList(growable: false),
                ),
              const SizedBox(height: 12),
            ] else
              Text(
                'Tài khoản này chỉ có quyền xem dữ liệu và cảnh báo của thiết bị này.',
                style: theme.textTheme.bodySmall,
              ),
            Flex(
              direction: Axis.horizontal,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Theo dõi thiết bị này'),
                  ),
                ),
                if (device.isOwnerLink) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onManageViewers();
                      },
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('Quản lý người xem'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _linkedUserLabel(DeviceLinkedUser user) {
  final segments = <String>[user.displayName];
  final linkRole = user.normalizedLinkRole ?? '';
  final phoneNumber = user.phoneNumber?.trim() ?? '';

  if (linkRole.isNotEmpty) {
    segments.add('Quyền trên thiết bị này: ${deviceAccessRoleLabel(linkRole)}');
  }
  if (phoneNumber.isNotEmpty) {
    segments.add(phoneNumber);
  }

  return segments.join(' | ');
}

Future<String?> _showRenameDeviceDialog(
  BuildContext context, {
  required String initialName,
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDeviceDialog(initialName: initialName),
  );
}

class _RenameDeviceDialog extends StatefulWidget {
  const _RenameDeviceDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDeviceDialog> createState() => _RenameDeviceDialogState();
}

class _RenameDeviceDialogState extends State<_RenameDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName.trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên thiết bị'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Tên hiển thị trên ứng dụng',
            hintText: 'Ví dụ: Máy đo phòng ngủ',
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nhập tên thiết bị';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.color,
    required this.textColor,
    required this.message,
  });

  final Color color;
  final Color textColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.devices_other_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoginFormContent extends StatefulWidget {
  const _LoginFormContent({
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.isAuthenticating,
    required this.errorMessage,
    required this.onLogin,
    required this.onRegister,
  });

  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final bool isAuthenticating;
  final String? errorMessage;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  State<_LoginFormContent> createState() => _LoginFormContentState();
}

class _LoginFormContentState extends State<_LoginFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (AppValidators.validatePhoneNumber(widget.phoneCtrl.text) != null) {
        _phoneFocusNode.requestFocus();
      } else if ((widget.passwordCtrl.text).isEmpty) {
        _passwordFocusNode.requestFocus();
      }
      return;
    }
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: AppBrandLockup(
                logoSize: 84,
                subtitle:
                    'Kết nối thiết bị, theo dõi chỉ số sức khỏe và quản lý quyền xem trong cùng một nơi.',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Đăng nhập để tải danh sách thiết bị đã liên kết',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Sau khi đăng nhập, hệ thống sẽ tải thông tin tài khoản và danh sách thiết bị đã liên kết của bạn.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: widget.phoneCtrl,
              focusNode: _phoneFocusNode,
              autofocus: true,
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: AppValidators.validatePhoneNumber,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.passwordCtrl,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return AppStrings.loginPasswordRequired;
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (widget.errorMessage != null &&
                widget.errorMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InlineBanner(
                color: Theme.of(context).colorScheme.errorContainer,
                textColor: Theme.of(context).colorScheme.onErrorContainer,
                message: widget.errorMessage!,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.isAuthenticating ? null : _submit,
                icon: widget.isAuthenticating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  widget.isAuthenticating ? 'Đang đăng nhập...' : 'Đăng nhập',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.isAuthenticating ? null : widget.onRegister,
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatDateOfBirth(String? raw) {
  return AppDateUtils.formatDateOfBirth(raw);
}
