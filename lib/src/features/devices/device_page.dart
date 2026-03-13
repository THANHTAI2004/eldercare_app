import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/config/env.dart';
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
  final _loginUserCtrl = TextEditingController(
    text: kDebugMode ? Env.loginUserId : '',
  );
  final _loginPasswordCtrl = TextEditingController(
    text: kDebugMode && Env.loginPassword != 'replace-with-password'
        ? Env.loginPassword
        : '',
  );

  String _query = '';
  String? _lastRealtimeBindingKey;

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
    _loginUserCtrl.dispose();
    _loginPasswordCtrl.dispose();
    super.dispose();
  }

  bool get _supportsQrScan {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _bindCurrentDeviceToRealtime() {
    final realtime = context.read<RealtimeProvider>();
    final current = context.read<DeviceProvider>().current;
    final userId = current?.primaryUserId ?? realtime.authenticatedUserId;
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
    final userId = _loginUserCtrl.text.trim();
    final password = _loginPasswordCtrl.text;
    if (userId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhap user ID va mat khau de dang nhap.')),
      );
      return;
    }

    final realtime = context.read<RealtimeProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final ok = await realtime.login(userId: userId, password: password);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(realtime.error ?? 'Dang nhap that bai.')),
      );
      return;
    }

    await deviceProvider.syncFromServer(
      authenticatedUserId: realtime.authenticatedUserId,
    );

    final current = deviceProvider.current;
    if (current != null) {
      await realtime.init(
        userId: current.primaryUserId ?? realtime.authenticatedUserId,
        deviceId: current.resolvedDeviceId,
      );
    }
  }

  Future<void> _refreshDevices() async {
    final realtime = context.read<RealtimeProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    if (realtime.isAuthenticated) {
      await deviceProvider.syncFromServer(
        authenticatedUserId: realtime.authenticatedUserId,
      );
      final current = deviceProvider.current;
      if (current != null) {
        await realtime.init(
          userId: current.primaryUserId ?? realtime.authenticatedUserId,
          deviceId: current.resolvedDeviceId,
        );
      }
      return;
    }

    await deviceProvider.ensureDevFallback();
  }

  Future<void> _logout() async {
    final realtime = context.read<RealtimeProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    await realtime.logout();
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

  bool _canUseUserId(String? userId) {
    final realtime = context.read<RealtimeProvider>();
    final normalizedUserId = userId?.trim() ?? '';
    if (!realtime.isUserScopedSession || normalizedUserId.isEmpty) return true;
    if (normalizedUserId == realtime.authenticatedUserId) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session hien tai chi duoc theo doi user ${realtime.authenticatedUserId}.',
        ),
      ),
    );
    return false;
  }

  Future<void> _selectDevice(Device device) async {
    if (!_canUseUserId(device.primaryUserId)) return;

    final deviceProvider = context.read<DeviceProvider>();
    final realtime = context.read<RealtimeProvider>();

    await deviceProvider.setCurrent(device.id);
    await realtime.changeUser(
      device.primaryUserId ?? realtime.authenticatedUserId,
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

    final realtime = context.read<RealtimeProvider>();
    final formKey = GlobalKey<FormState>();
    final lockedUserId = realtime.isUserScopedSession
        ? realtime.authenticatedUserId
        : '';
    final userCtrl = TextEditingController(text: lockedUserId);
    final deviceCtrl = TextEditingController(text: Env.defaultDeviceId);
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
    if (!_canUseUserId(userCtrl.text)) return;

    final payload = <String, dynamic>{
      'userId': userCtrl.text.trim(),
      'deviceId': deviceCtrl.text.trim(),
      if (nameCtrl.text.trim().isNotEmpty) 'name': nameCtrl.text.trim(),
    };

    final deviceProvider = context.read<DeviceProvider>();
    final realtimeProvider = context.read<RealtimeProvider>();
    await deviceProvider.addFromQr(jsonEncode(payload));

    final current = deviceProvider.current;
    if (current != null) {
      await realtimeProvider.init(
        userId: current.primaryUserId ?? realtimeProvider.authenticatedUserId,
        deviceId: current.resolvedDeviceId,
      );
    }
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
    if (!_canUseUserId(parsed.primaryUserId)) return;

    final deviceProvider = context.read<DeviceProvider>();
    final realtimeProvider = context.read<RealtimeProvider>();
    await deviceProvider.addFromQr(code);

    final current = deviceProvider.current;
    if (current != null) {
      await realtimeProvider.init(
        userId: current.primaryUserId ?? realtimeProvider.authenticatedUserId,
        deviceId: current.resolvedDeviceId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final realtime = context.watch<RealtimeProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    _bindCurrentDeviceToRealtime();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          realtime.isAuthenticated ? 'Thiet bi da lien ket' : 'Dang nhap',
        ),
        actions: [
          IconButton(
            tooltip: 'Lam moi',
            onPressed: _refreshDevices,
            icon: const Icon(Icons.refresh),
          ),
          if (realtime.isAuthenticated)
            IconButton(
              tooltip: 'Dang xuat',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      floatingActionButton: kDebugMode && realtime.isAuthenticated
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
      body: realtime.isAuthenticated
          ? _AuthenticatedBody(
              query: _query,
              searchCtrl: _searchCtrl,
              deviceProvider: deviceProvider,
              realtime: realtime,
              onRefresh: _refreshDevices,
              onSelectDevice: _selectDevice,
            )
          : _LoginBody(
              userCtrl: _loginUserCtrl,
              passwordCtrl: _loginPasswordCtrl,
              isAuthenticating: realtime.isAuthenticating,
              errorMessage: realtime.error,
              onLogin: _login,
            ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.userCtrl,
    required this.passwordCtrl,
    required this.isAuthenticating,
    required this.errorMessage,
    required this.onLogin,
  });

  final TextEditingController userCtrl;
  final TextEditingController passwordCtrl;
  final bool isAuthenticating;
  final String? errorMessage;
  final Future<void> Function() onLogin;

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
                    TextField(
                      controller: userCtrl,
                      decoration: const InputDecoration(labelText: 'User ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mat khau'),
                      onSubmitted: (_) => onLogin(),
                    ),
                    if (errorMessage != null &&
                        errorMessage!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InlineBanner(
                        color: Theme.of(context).colorScheme.errorContainer,
                        textColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                        message: errorMessage!,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isAuthenticating ? null : onLogin,
                      icon: isAuthenticating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        isAuthenticating ? 'Dang dang nhap...' : 'Dang nhap',
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Che do debug van giu USER_ID / DEVICE_ID lam fallback neu tai khoan chua co device.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
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
    required this.realtime,
    required this.onRefresh,
    required this.onSelectDevice,
  });

  final String query;
  final TextEditingController searchCtrl;
  final DeviceProvider deviceProvider;
  final RealtimeProvider realtime;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Device device) onSelectDevice;

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
            userId: realtime.authenticatedUserId,
            role: realtime.authenticatedRole,
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
              hintText: 'Tim theo ten device, device_id, user lien ket...',
            ),
          ),
          const SizedBox(height: 16),
          if (deviceProvider.isSyncing && deviceProvider.devices.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (devices.isEmpty)
            _EmptyState(
              message: deviceProvider.devices.isEmpty
                  ? 'Tai khoan nay chua co thiet bi lien ket.'
                  : 'Khong co thiet bi nao khop bo loc hien tai.',
            )
          else
            ...devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceCard(
                  device: device,
                  isCurrent: deviceProvider.current?.id == device.id,
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
    required this.userId,
    required this.role,
    required this.totalDevices,
    required this.currentDevice,
  });

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
              'Session hien tai',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('User: $userId'),
            Text('Role: ${role.isEmpty ? 'unknown' : role}'),
            Text('So thiet bi linked: $totalDevices'),
            const SizedBox(height: 8),
            Text(
              currentDevice == null
                  ? 'Chua chon thiet bi nao.'
                  : 'Dang theo doi: ${currentDevice!.name} (${currentDevice!.resolvedDeviceId})',
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
    required this.onSelect,
  });

  final Device device;
  final bool isCurrent;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkedUsers = device.linkedUsers;

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
                      Text('device_id: ${device.resolvedDeviceId}'),
                      if (device.primaryUserId != null)
                        Text('user chinh: ${device.primaryUserId}'),
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
            if (device.isLocalOnly) ...[
              const SizedBox(height: 12),
              _InlineBanner(
                color: theme.colorScheme.primaryContainer,
                textColor: theme.colorScheme.onPrimaryContainer,
                message:
                    'Device nay dang duoc giu lam fallback debug, khong phai linked device chinh tu server.',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Nguoi da lien ket voi thiet bi',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (linkedUsers.isEmpty)
              Text(
                'Response hien tai chua tra danh sach linked users cho device nay.',
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: linkedUsers
                    .map(
                      (user) => Chip(
                        label: Text(
                          user.role == null || user.role!.trim().isEmpty
                              ? user.displayName
                              : '${user.displayName} (${user.role})',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('Theo doi device nay'),
            ),
          ],
        ),
      ),
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
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.devices_other_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
