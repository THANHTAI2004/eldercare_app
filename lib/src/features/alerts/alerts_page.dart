import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/alert_item.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/alert_card.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/device_selector.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

enum _AckFilter { all, pending, acknowledged }
enum _SeverityFilter { all, low, medium, high }

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String? _lastScopeKey;
  _AckFilter _ackFilter = _AckFilter.pending;
  _SeverityFilter _severityFilter = _SeverityFilter.all;

  void _syncScope() {
    final provider = context.read<AlertsProvider>();
    final device = context.read<DeviceProvider>().current;
    final nextScopeKey = '${provider.isAuthenticated}::${device?.resolvedDeviceId ?? ''}';
    if (_lastScopeKey == nextScopeKey) return;
    _lastScopeKey = nextScopeKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      provider.bindDevice(device?.resolvedDeviceId ?? '');
      await provider.loadAlerts();
    });
  }

  Future<void> _selectDevice(String? deviceId) async {
    final selectedId = deviceId?.trim() ?? '';
    if (selectedId.isEmpty) return;
    final deviceProvider = context.read<DeviceProvider>();
    await deviceProvider.setCurrent(selectedId);
    final current = deviceProvider.current;
    if (!mounted || current == null) return;
    final alerts = context.read<AlertsProvider>();
    alerts.bindDevice(current.resolvedDeviceId);
    await alerts.loadAlerts();
  }

  Future<void> _refresh() => context.read<AlertsProvider>().loadAlerts();

  Future<void> _confirmAcknowledge(AlertItem alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận cảnh báo'),
        content: Text(
          'Bạn có chắc muốn đánh dấu cảnh báo "${alert.title}" là đã xử lý?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AlertsProvider>().acknowledge(alert.id);
  }

  Future<void> _showDetails(AlertItem alert) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(alert.message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            StatusBadge(
              label: _severityLabel(alert.severity),
              tone: _severityTone(alert.severity),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Thời gian: ${DateFormat('HH:mm, dd/MM/yyyy').format(alert.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if ((alert.deviceId ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Device ID: ${alert.deviceId}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsProvider = context.watch<AlertsProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final currentDevice = deviceProvider.current;
    _syncScope();

    final visibleAlerts = alertsProvider.items.where((alert) {
      if (_ackFilter == _AckFilter.pending && alert.acknowledged) return false;
      if (_ackFilter == _AckFilter.acknowledged && !alert.acknowledged) {
        return false;
      }

      final severity = _severityGroup(alert.severity);
      if (_severityFilter == _SeverityFilter.low && severity != _SeverityFilter.low) {
        return false;
      }
      if (_severityFilter == _SeverityFilter.medium &&
          severity != _SeverityFilter.medium) {
        return false;
      }
      if (_severityFilter == _SeverityFilter.high && severity != _SeverityFilter.high) {
        return false;
      }

      return true;
    }).toList(growable: false);

    return AppScaffold(
      title: 'Cảnh báo',
      subtitle: 'Theo dõi và xử lý cảnh báo kịp thời theo từng thiết bị.',
      actions: [
        IconButton(
          onPressed: alertsProvider.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (currentDevice != null)
              DeviceSelector(
                devices: deviceProvider.devices,
                currentDeviceId: currentDevice.id,
                onChanged: _selectDevice,
                isBusy: alertsProvider.isLoading,
              )
            else
              const EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Chưa có thiết bị theo dõi',
                message: 'Hãy chọn thiết bị để tải danh sách cảnh báo.',
              ),
            const SizedBox(height: AppSpacing.xl),
            _FilterChips(
              ackFilter: _ackFilter,
              severityFilter: _severityFilter,
              onAckChanged: (value) => setState(() => _ackFilter = value),
              onSeverityChanged: (value) => setState(() => _severityFilter = value),
            ),
            if (currentDevice != null && !currentDevice.isOwnerLink) ...[
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                backgroundColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                child: Text(
                  'Bạn đang ở chế độ chỉ xem trên thiết bị này. Chỉ chủ thiết bị mới có thể đánh dấu đã xử lý cảnh báo.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            if (alertsProvider.isLoading && alertsProvider.items.isEmpty)
              const LoadingState(message: 'Đang tải cảnh báo...')
            else if (visibleAlerts.isEmpty)
              const EmptyState(
                icon: Icons.notification_important_outlined,
                title: 'Không có cảnh báo phù hợp',
                message:
                    'Bộ lọc hiện tại không khớp với cảnh báo nào, hoặc thiết bị chưa phát sinh cảnh báo.',
              )
            else
              ...visibleAlerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: AppAlertCard(
                    alert: alert,
                    deviceLabel: currentDevice?.name,
                    canAcknowledge: currentDevice?.isOwnerLink == true,
                    onDetails: () => _showDetails(alert),
                    onAcknowledge: () => _confirmAcknowledge(alert),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.ackFilter,
    required this.severityFilter,
    required this.onAckChanged,
    required this.onSeverityChanged,
  });

  final _AckFilter ackFilter;
  final _SeverityFilter severityFilter;
  final ValueChanged<_AckFilter> onAckChanged;
  final ValueChanged<_SeverityFilter> onSeverityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: ackFilter == _AckFilter.all,
              onSelected: (_) => onAckChanged(_AckFilter.all),
            ),
            ChoiceChip(
              label: const Text('Chưa xử lý'),
              selected: ackFilter == _AckFilter.pending,
              onSelected: (_) => onAckChanged(_AckFilter.pending),
            ),
            ChoiceChip(
              label: const Text('Đã xử lý'),
              selected: ackFilter == _AckFilter.acknowledged,
              onSelected: (_) => onAckChanged(_AckFilter.acknowledged),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: severityFilter == _SeverityFilter.all,
              onSelected: (_) => onSeverityChanged(_SeverityFilter.all),
            ),
            ChoiceChip(
              label: const Text('Nhẹ'),
              selected: severityFilter == _SeverityFilter.low,
              onSelected: (_) => onSeverityChanged(_SeverityFilter.low),
            ),
            ChoiceChip(
              label: const Text('Trung bình'),
              selected: severityFilter == _SeverityFilter.medium,
              onSelected: (_) => onSeverityChanged(_SeverityFilter.medium),
            ),
            ChoiceChip(
              label: const Text('Nguy hiểm'),
              selected: severityFilter == _SeverityFilter.high,
              onSelected: (_) => onSeverityChanged(_SeverityFilter.high),
            ),
          ],
        ),
      ],
    );
  }
}

_SeverityFilter _severityGroup(String severity) {
  switch (severity.trim().toLowerCase()) {
    case 'low':
      return _SeverityFilter.low;
    case 'medium':
      return _SeverityFilter.medium;
    case 'high':
    case 'critical':
      return _SeverityFilter.high;
    default:
      return _SeverityFilter.all;
  }
}

String _severityLabel(String severity) {
  switch (severity.trim().toLowerCase()) {
    case 'low':
      return 'Nhẹ';
    case 'medium':
      return 'Trung bình';
    case 'high':
    case 'critical':
      return 'Nguy hiểm';
    default:
      return 'Không rõ';
  }
}

StatusTone _severityTone(String severity) {
  switch (severity.trim().toLowerCase()) {
    case 'low':
      return StatusTone.success;
    case 'medium':
      return StatusTone.warning;
    case 'high':
    case 'critical':
      return StatusTone.danger;
    default:
      return StatusTone.neutral;
  }
}
