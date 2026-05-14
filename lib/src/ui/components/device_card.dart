import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class AppDeviceCard extends StatelessWidget {
  const AppDeviceCard({
    super.key,
    required this.device,
    required this.isCurrent,
    this.isOnline,
    this.onTrack,
    this.onManage,
  });

  final Device device;
  final bool isCurrent;
  final bool? isOnline;
  final FutureOr<void> Function()? onTrack;
  final FutureOr<void> Function()? onManage;

  @override
  Widget build(BuildContext context) {
    final viewersCount = device.linkedUsers.where((user) => user.isViewerLink).length;
    final initials = device.name.trim().isEmpty
        ? 'EC'
        : device.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                foregroundColor: AppColors.primary,
                child: Text(initials),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      device.resolvedDeviceId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                const StatusBadge(
                  label: 'Đang theo dõi',
                  tone: StatusTone.info,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: (isOnline == null)
                    ? 'Chưa có trạng thái'
                    : (isOnline! ? 'Online' : 'Offline'),
                tone: isOnline == null
                    ? StatusTone.neutral
                    : (isOnline! ? StatusTone.success : StatusTone.warning),
              ),
              StatusBadge(
                label: deviceAccessRoleLabel(device.normalizedLinkRole),
                tone: device.isOwnerLink ? StatusTone.info : StatusTone.neutral,
              ),
              StatusBadge(
                label: '$viewersCount người xem',
                tone: StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Theo dõi',
                  onPressed: onTrack,
                  icon: const Icon(Icons.favorite_border_rounded),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SecondaryButton(
                  label: 'Quản lý',
                  onPressed: onManage,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
