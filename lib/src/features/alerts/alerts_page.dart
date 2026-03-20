import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/app_layout.dart';
import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/domain/models/alert_item.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/features/devices/device_viewers_page.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String? _lastScopeKey;

  void _syncAlertScope(String? deviceId, AlertsProvider provider) {
    final nextDeviceId = deviceId?.trim() ?? '';
    final nextScopeKey = '${provider.isAuthenticated}::$nextDeviceId';
    if (_lastScopeKey == nextScopeKey) return;
    _lastScopeKey = nextScopeKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      provider.bindDevice(nextDeviceId);
      await provider.loadAlerts();
    });
  }

  Future<void> _openAlertDevice(Device device) async {
    await context.read<DeviceProvider>().setCurrent(device.id);
    if (!mounted) return;
    Navigator.pop(context, device.resolvedDeviceId);
  }

  Future<void> _openOwnerManagement(Device device) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceViewersPage(device: device)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertsProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final currentDeviceId = deviceProvider.current?.resolvedDeviceId;
    final contentMaxWidth = AppLayout.maxContentWidth(context);
    final pagePadding = AppLayout.pagePadding(
      context,
      compact: 12,
      medium: 20,
      expanded: 24,
      bottom: 20,
    );
    _syncAlertScope(currentDeviceId, provider);
    final visibleItems = provider.visibleItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: provider.isLoading
                ? null
                : () => context.read<AlertsProvider>().loadAlerts(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AlertsProvider>().loadAlerts(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: ListView(
              padding: pagePadding,
              children: [
                _SummaryCard(activeCount: provider.activeCount),
                const SizedBox(height: 12),
                Flex(
                  direction: Axis.horizontal,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AlertSeverityFilter>(
                        isExpanded: true,
                        initialValue: provider.severityFilter,
                        decoration: const InputDecoration(labelText: 'Mức độ'),
                        items: const [
                          DropdownMenuItem(
                            value: AlertSeverityFilter.all,
                            child: Text('Tất cả'),
                          ),
                          DropdownMenuItem(
                            value: AlertSeverityFilter.highOnly,
                            child: Text('Cao và khẩn cấp'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            context
                                .read<AlertsProvider>()
                                .setSeverityFilter(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<AlertAckFilter>(
                        isExpanded: true,
                        initialValue: provider.ackFilter,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AlertAckFilter.activeOnly,
                            child: Text('Chưa xử lý'),
                          ),
                          DropdownMenuItem(
                            value: AlertAckFilter.acknowledgedOnly,
                            child: Text('Đã xử lý'),
                          ),
                          DropdownMenuItem(
                            value: AlertAckFilter.all,
                            child: Text('Tất cả'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            context.read<AlertsProvider>().setAckFilter(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (provider.error != null &&
                    provider.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    message: provider.error!,
                    isError: provider.lastErrorStatusCode != 404,
                  ),
                ] else if ((currentDeviceId ?? '').isEmpty) ...[
                  const SizedBox(height: 12),
                  const _Banner(
                    message:
                        'Chưa có thiết bị đang theo dõi để tải cảnh báo.',
                    isError: false,
                  ),
                ],
                const SizedBox(height: 16),
                if (provider.isLoading && provider.items.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (visibleItems.isEmpty)
                  const _EmptyAlertsState()
                else
                  ...visibleItems.map((item) {
                    final linkedDevice = deviceProvider.findById(item.deviceId);
                    final canAcknowledge = linkedDevice?.isOwnerLink == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AlertCard(
                        item: item,
                        linkedDevice: linkedDevice,
                        showAcknowledgeAction: canAcknowledge,
                        onAcknowledge:
                            !canAcknowledge ||
                                item.acknowledged ||
                                provider.isAcknowledging
                            ? null
                            : () => context
                                .read<AlertsProvider>()
                                .acknowledge(item.id),
                        onOpenDevice: linkedDevice == null
                            ? null
                            : () => _openAlertDevice(linkedDevice),
                        onManageDevice:
                            linkedDevice != null && linkedDevice.isOwnerLink
                            ? () => _openOwnerManagement(linkedDevice)
                            : null,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activeCount == 0
                    ? 'Không có cảnh báo chưa xử lý'
                    : '$activeCount cảnh báo chưa xử lý',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.item,
    required this.linkedDevice,
    required this.showAcknowledgeAction,
    required this.onAcknowledge,
    required this.onOpenDevice,
    required this.onManageDevice,
  });

  final AlertItem item;
  final Device? linkedDevice;
  final bool showAcknowledgeAction;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onOpenDevice;
  final VoidCallback? onManageDevice;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final scheme = Theme.of(context).colorScheme;
    final severity = item.severity.toUpperCase();
    final bannerColor = item.isHighSeverity
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final textColor = item.isHighSeverity
        ? scheme.onErrorContainer
        : scheme.onSurface;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(severity)),
                if (item.acknowledged)
                  const Chip(
                    avatar: Icon(Icons.check, size: 18),
                    label: Text('Đã xử lý'),
                  ),
                if (linkedDevice != null)
                  Chip(
                    label: Text(
                      deviceAccessRoleLabel(linkedDevice!.normalizedLinkRole),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('Lúc tạo: ${item.createdAt.toLocal()}'),
            if (item.deviceId != null) Text('Mã thiết bị: ${item.deviceId}'),
            if (linkedDevice != null) ...[
              const SizedBox(height: 4),
              Text('Thiết bị trong ứng dụng: ${linkedDevice!.name}'),
            ],
            if (linkedDevice == null && item.deviceId != null) ...[
              const SizedBox(height: 4),
              const Text(
                'Thiết bị này hiện không có trong danh sách thiết bị được cấp quyền.',
              ),
            ],
            const SizedBox(height: 12),
            if (showAcknowledgeAction || onOpenDevice != null)
              Flex(
                direction: Axis.horizontal,
                children: [
                  if (showAcknowledgeAction)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAcknowledge,
                        icon: const Icon(Icons.done_all),
                        label: Text(
                          item.acknowledged
                              ? 'Đã xử lý'
                              : 'Đánh dấu đã xử lý',
                        ),
                      ),
                    ),
                  if (showAcknowledgeAction && onOpenDevice != null)
                    const SizedBox(width: 12),
                  if (onOpenDevice != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenDevice,
                        icon: const Icon(Icons.monitor_heart_outlined),
                        label: const Text('Mở thiết bị'),
                      ),
                    ),
                ],
              ),
            if (!showAcknowledgeAction &&
                linkedDevice != null &&
                linkedDevice!.isViewerLink) ...[
              const SizedBox(height: 8),
              Text(
                'Bạn đang ở chế độ chỉ xem trên thiết bị này. Chỉ chủ thiết bị mới có thể đánh dấu đã xử lý cảnh báo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onManageDevice != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onManageDevice,
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Quản lý người xem'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.errorContainer : scheme.primaryContainer;
    final textColor = isError
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;

    return Container(
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

class _EmptyAlertsState extends StatelessWidget {
  const _EmptyAlertsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.notifications_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Không có cảnh báo phù hợp với bộ lọc hiện tại.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
