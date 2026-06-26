import 'package:flutter/material.dart';

import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class DeviceSelector extends StatelessWidget {
  const DeviceSelector({
    super.key,
    required this.devices,
    required this.currentDeviceId,
    required this.onChanged,
    this.onOpenDevices,
    this.isBusy = false,
    this.isOnline,
  });

  final List<Device> devices;
  final String? currentDeviceId;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onOpenDevices;
  final bool isBusy;
  final bool? isOnline;

  @override
  Widget build(BuildContext context) {
    Device? current;
    for (final device in devices) {
      if (device.id == currentDeviceId) {
        current = device;
        break;
      }
    }
    final dropdownValue = devices.any((device) => device.id == currentDeviceId)
        ? currentDeviceId
        : null;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Đang theo dõi',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (isBusy) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              if (onOpenDevices != null)
                TextButton.icon(
                  onPressed: onOpenDevices,
                  icon: const Icon(Icons.devices_outlined, size: 16),
                  label: const Text('Danh sách', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Chọn thiết bị',
              prefixIcon: Icon(Icons.watch_outlined, size: 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: devices
                .map(
                  (device) => DropdownMenuItem<String>(
                    value: device.id,
                    child: Text(
                      '${device.name} • ${device.resolvedDeviceId}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: devices.length <= 1 ? null : onChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (current != null)
                StatusBadge(
                  label: isOnline == null
                      ? 'Chưa có trạng thái'
                      : (isOnline! ? 'Online' : 'Offline'),
                  tone: isOnline == null
                      ? StatusTone.neutral
                      : (isOnline! ? StatusTone.success : StatusTone.warning),
                  icon: isOnline == null
                      ? Icons.watch_outlined
                      : (isOnline!
                          ? Icons.wifi_tethering_rounded
                          : Icons.wifi_off_rounded),
                ),
              StatusBadge(
                label: current == null
                    ? 'Chưa chọn thiết bị'
                    : deviceAccessRoleLabel(current.normalizedLinkRole),
                tone: current?.isOwnerLink == true
                    ? StatusTone.info
                    : StatusTone.neutral,
              ),
              if (current != null)
                StatusBadge(
                  label: '${current.linkedUsers.length} tài khoản liên kết',
                  tone: StatusTone.neutral,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
