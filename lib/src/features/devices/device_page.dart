import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/core/app_date_utils.dart';
import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/claim_device_page.dart';
import 'package:eldercare_app/src/features/devices/device_qr_scanner_page.dart';
import 'package:eldercare_app/src/features/devices/device_viewers_page.dart';
import 'package:eldercare_app/src/features/home/home_page.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _searchCtrl = TextEditingController();
  final _loginPhoneCtrl = TextEditingController(
    text: kDebugMode ? Env.debugLoginPhoneNumber : '',
  );
  final _loginPasswordCtrl = TextEditingController(
    text: kDebugMode && Env.debugLoginPassword != 'replace-with-password'
        ? Env.debugLoginPassword
        : '',
  );

  String _query = '';
  String? _lastRealtimeBindingKey;
  String? _lastSessionMessage;
  DeviceProvider? _deviceProvider;

  @override
  void initState() {
    super.initState();
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

  bool get _supportsQrScan {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _handleDeviceProviderChanged() {
    _bindCurrentDeviceToRealtime();
  }

  void _bindCurrentDeviceToRealtime() {
    final realtime = context.read<RealtimeProvider>();
    final session = context.read<SessionProvider>();
    final current = context.read<DeviceProvider>().current;
    final userId = current?.primaryUserId ?? session.authenticatedUserId;
    final deviceId = current?.resolvedDeviceId ?? '';
    final bindingKey = '$userId::$deviceId';

    if (_lastRealtimeBindingKey == bindingKey) return;
    _lastRealtimeBindingKey = bindingKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || current == null) return;
      await realtime.init(userId: userId, deviceId: deviceId);
    });
  }

  Future<void> _login() async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final ok = await session.login(
      phoneNumber: _loginPhoneCtrl.text.trim(),
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
        content: Text('Tao tai khoan thanh cong. Vui long dang nhap.'),
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

    await deviceProvider.ensureDevFallback();
  }

  Future<void> _openClaimDevice() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ClaimDevicePage()),
    );
    if (result != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien ket thiet bi thanh cong.')),
    );
  }

  Future<void> _logout() async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    await session.logout();
    await deviceProvider.clear();
    if (kDebugMode) {
      await deviceProvider.ensureDevFallback();
    }

    _lastRealtimeBindingKey = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Da dang xuat phien hien tai.')),
    );
  }

  bool _canUseUserId(String? userId, {String? deviceId}) {
    if ((deviceId?.trim().isNotEmpty ?? false)) return true;

    final session = context.read<SessionProvider>();
    final normalizedUserId = userId?.trim() ?? '';
    if (!session.isUserScopedSession || normalizedUserId.isEmpty) return true;
    if (normalizedUserId == session.authenticatedUserId) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session hien tai chi duoc theo doi user ${session.authenticatedUserId}.',
        ),
      ),
    );
    return false;
  }

  Future<void> _selectDevice(Device device) async {
    if (!_canUseUserId(
      device.primaryUserId,
      deviceId: device.resolvedDeviceId,
    )) {
      return;
    }

    final deviceProvider = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();
    final session = context.read<SessionProvider>();

    await deviceProvider.setCurrent(device.id);
    await realtime.changeUser(
      device.primaryUserId ?? session.authenticatedUserId,
      deviceId: device.resolvedDeviceId,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _showManualAddDialog() async {
    if (!kDebugMode) return;

    final session = context.read<SessionProvider>();
    final formKey = GlobalKey<FormState>();
    final lockedUserId = session.isUserScopedSession
        ? session.authenticatedUserId
        : '';
    final userCtrl = TextEditingController(text: lockedUserId);
    final deviceCtrl = TextEditingController(text: Env.debugDefaultDeviceId);
    final nameCtrl = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Them device fallback'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: userCtrl,
                readOnly: lockedUserId.isNotEmpty,
                decoration: const InputDecoration(labelText: 'user_id'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nhap user_id';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: deviceCtrl,
                decoration: const InputDecoration(labelText: 'device_id'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nhap device_id';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Ten hien thi'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Luu'),
          ),
        ],
      ),
    );

    if (shouldSave != true || !mounted) return;
    if (!_canUseUserId(userCtrl.text, deviceId: deviceCtrl.text)) return;

    final payload = <String, dynamic>{
      'userId': userCtrl.text.trim(),
      'deviceId': deviceCtrl.text.trim(),
      if (nameCtrl.text.trim().isNotEmpty) 'name': nameCtrl.text.trim(),
    };

    final deviceProvider = context.read<DeviceProvider>();
    await deviceProvider.addFromQr(jsonEncode(payload));
  }

  Future<void> _scanAndAdd() async {
    if (!kDebugMode) return;
    if (!_supportsQrScan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nen tang hien tai chua ho tro quet QR.')),
      );
      return;
    }

    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DeviceQrScannerPage()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    final parsed = Device.fromQr(code);
    if (!_canUseUserId(
      parsed.primaryUserId,
      deviceId: parsed.resolvedDeviceId,
    )) {
      return;
    }

    final deviceProvider = context.read<DeviceProvider>();
    await deviceProvider.addFromQr(code);
  }

  Future<void> _handleLinkDevice() async {
    await _openClaimDevice();
  }

  Future<void> _showLinkGuideDialog() async {
    const content =
        'Neu ban la chu thiet bi, hay dung chuc nang them thiet bi bang ma thiet bi de lien ket thiet bi.\n\n'
        'Neu ban chi can quyen xem, vui long lien he owner cua thiet bi de duoc them vao danh sach viewer.';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huong dan lien ket thiet bi'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dong'),
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
    _handleSessionFeedback(session);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.isAuthenticated ? 'Thiet bi da lien ket' : 'Dang nhap',
        ),
        actions: [
          if (session.isAuthenticated)
            IconButton(
              tooltip: 'Lien ket thiet bi',
              onPressed: _openClaimDevice,
              icon: const Icon(Icons.add_link),
            ),
          IconButton(
            tooltip: 'Lam moi',
            onPressed: _refreshDevices,
            icon: const Icon(Icons.refresh),
          ),
          if (session.isAuthenticated)
            IconButton(
              tooltip: 'Dang xuat',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      floatingActionButton: kDebugMode && session.isAuthenticated
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'manual-fallback-device',
                  onPressed: _showManualAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Them fallback'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'scan-fallback-device',
                  onPressed: _scanAndAdd,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_supportsQrScan ? 'Quet QR' : 'Khong co QR'),
                ),
              ],
            )
          : null,
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: const EdgeInsets.all(24),
          shrinkWrap: true,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
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

  @override
  Widget build(BuildContext context) {
    final devices = deviceProvider.devices
        .where((device) {
          if (query.isEmpty) return true;

          final haystacks = <String>[
            device.name.toLowerCase(),
            device.resolvedDeviceId.toLowerCase(),
            if (device.primaryUserId != null)
              device.primaryUserId!.toLowerCase(),
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _SessionCard(
            name: session.currentUser?.name ?? '',
            phoneNumber: session.currentUser?.phoneNumber ?? '',
            dateOfBirth: session.currentUser?.dateOfBirth,
            userId: session.authenticatedUserId,
            role: session.authenticatedRoleLabel,
            totalDevices: deviceProvider.devices.length,
            currentDevice: deviceProvider.current,
          ),
          if (realtime.error != null && realtime.error!.trim().isNotEmpty) ...[
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
                  'Tim theo ten thiet bi, ma thiet bi, tai khoan lien ket...',
            ),
          ),
          const SizedBox(height: 16),
          if (deviceProvider.isSyncing && deviceProvider.devices.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (devices.isEmpty)
            _EmptyState(
              title: deviceProvider.devices.isEmpty
                  ? 'Ban chua co thiet bi nao'
                  : 'Khong co thiet bi phu hop',
              message: deviceProvider.devices.isEmpty
                  ? 'Ban co the them thiet bi bang ma thiet bi de lien ket thiet bi. Neu ban chi can quyen xem, vui long lien he chu thiet bi de duoc cap quyen viewer.'
                  : 'Thu doi bo loc tim kiem hoac lam moi danh sach thiet bi.',
              actionLabel: deviceProvider.devices.isEmpty
                  ? 'Them thiet bi bang ma thiet bi'
                  : null,
              onAction: deviceProvider.devices.isEmpty ? onLinkDevice : null,
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
                  onSelect: () => onSelectDevice(device),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.name,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.userId,
    required this.role,
    required this.totalDevices,
    required this.currentDevice,
  });

  final String name;
  final String phoneNumber;
  final String? dateOfBirth;
  final String userId;
  final String role;
  final int totalDevices;
  final Device? currentDevice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thong tin tai khoan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Ten: ${name.trim().isEmpty ? 'Chua cap nhat' : name}'),
            Text(
              'SDT: ${phoneNumber.trim().isEmpty ? 'Chua cap nhat' : phoneNumber}',
            ),
            Text(
              'Ngay sinh: ${_formatDateOfBirth(dateOfBirth) ?? 'Chua cap nhat'}',
            ),
            Text('Vai tro: ${role.isEmpty ? 'Chua cap nhat' : role}'),
            Text('So thiet bi da lien ket: $totalDevices'),
            const SizedBox(height: 8),
            Text(
              currentDevice == null
                  ? 'Chua chon thiet bi nao.'
                  : 'Dang theo doi: ${currentDevice!.name} (${currentDevice!.resolvedDeviceId})',
            ),
            const SizedBox(height: 8),
            if (kDebugMode && userId.isNotEmpty)
              Text(
                'Ma user noi bo: $userId',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
    required this.onSelect,
  });

  final Device device;
  final bool isCurrent;
  final Future<void> Function() onManageViewers;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewers = device.linkedUsers
        .where((user) => user.isViewerLink)
        .toList(growable: false);
    final roleLabel = _deviceAccessRoleLabel(device.normalizedLinkRole);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Text('Ma thiet bi: ${device.resolvedDeviceId}'),
                      if (device.primaryUserId != null)
                        Text('Tai khoan chinh: ${device.primaryUserId}'),
                      const SizedBox(height: 6),
                      Chip(label: Text('Quyen cua ban: $roleLabel')),
                    ],
                  ),
                ),
                if (isCurrent)
                  Chip(
                    avatar: const Icon(Icons.check, size: 18),
                    label: const Text('Dang theo doi'),
                  ),
              ],
            ),
            if (kDebugMode && device.isLocalOnly) ...[
              const SizedBox(height: 12),
              _InlineBanner(
                color: theme.colorScheme.primaryContainer,
                textColor: theme.colorScheme.onPrimaryContainer,
                message:
                    'Thiet bi nay dang duoc giu tam cho qua trinh thu nghiem, khong phai thiet bi lien ket chinh tu he thong.',
              ),
            ],
            const SizedBox(height: 12),
            if (device.isOwnerLink) ...[
              Text(
                'Viewer dang duoc chia se',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (viewers.isEmpty)
                Text(
                  'Chua co viewer nao duoc them vao thiet bi nay.',
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
                'Tai khoan nay chi co quyen xem du lieu va canh bao cua device nay.',
                style: theme.textTheme.bodySmall,
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Theo doi device nay'),
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
                      label: const Text('Quan ly viewer'),
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
  final role = user.role?.trim() ?? '';
  final linkRole = user.normalizedLinkRole ?? '';
  final phoneNumber = user.phoneNumber?.trim() ?? '';

  if (role.isNotEmpty) {
    segments.add('Vai tro: $role');
  }
  if (linkRole.isNotEmpty) {
    segments.add('Lien ket: ${_deviceAccessRoleLabel(linkRole)}');
  }
  if (phoneNumber.isNotEmpty) {
    segments.add(phoneNumber);
  }

  return segments.join(' | ');
}

String _deviceAccessRoleLabel(String? linkRole) {
  switch (linkRole) {
    case 'owner':
      return 'Owner';
    case 'viewer':
      return 'Viewer';
    default:
      return 'Khong ro';
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
            Text(
              'Dang nhap de tai danh sach thiet bi da lien ket',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Sau khi dang nhap, app se goi /api/v1/auth/me va /api/v1/me/devices de lay session user va thiet bi.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: widget.phoneCtrl,
              focusNode: _phoneFocusNode,
              autofocus: true,
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'So dien thoai'),
              validator: AppValidators.validatePhoneNumber,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.passwordCtrl,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Mat khau',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Hien mat khau' : 'An mat khau',
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
            FilledButton.icon(
              onPressed: widget.isAuthenticating ? null : _submit,
              icon: widget.isAuthenticating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                widget.isAuthenticating ? 'Dang dang nhap...' : 'Dang nhap',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.isAuthenticating ? null : widget.onRegister,
                child: const Text('Chua co tai khoan? Dang ky'),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                'Che do debug van cho phep them nhanh thiet bi thu nghiem neu tai khoan chua co thiet bi lien ket.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _formatDateOfBirth(String? raw) {
  return AppDateUtils.formatDateOfBirth(raw);
}
