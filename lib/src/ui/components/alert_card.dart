import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/alert_item.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class AppAlertCard extends StatelessWidget {
  const AppAlertCard({
    super.key,
    required this.alert,
    this.deviceLabel,
    this.onAcknowledge,
    this.onDetails,
    this.canAcknowledge = false,
    this.compact = false,
  });

  final AlertItem alert;
  final String? deviceLabel;
  final FutureOr<void> Function()? onAcknowledge;
  final FutureOr<void> Function()? onDetails;
  final bool canAcknowledge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final severity = _severityLabel(alert.severity);
    final tone = _severityTone(alert.severity);
    final highlight = !alert.acknowledged;

    return AppCard(
      padding: EdgeInsets.all(compact ? 12 : AppSpacing.lg),
      backgroundColor: highlight ? const Color(0xFFFFFBFB) : null,
      borderColor: highlight
          ? _severityColor(alert.severity).withValues(alpha: 0.35)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 44,
                height: compact ? 36 : 44,
                decoration: BoxDecoration(
                  color: _severityColor(alert.severity).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _severityIcon(alert.severity),
                  color: _severityColor(alert.severity),
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(alert.message, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: severity, tone: tone),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaRow(
                        icon: Icons.schedule_rounded,
                        text: DateFormat('HH:mm • dd/MM').format(alert.createdAt.toLocal()),
                      ),
                      StatusBadge(
                        label: alert.acknowledged ? 'Đã xử lý' : 'Chưa xử lý',
                        tone: alert.acknowledged ? StatusTone.success : StatusTone.warning,
                      ),
                    ],
                  ),
                ),
                if (canAcknowledge)
                  TextButton(
                    onPressed: alert.acknowledged ? null : onAcknowledge,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(alert.acknowledged ? 'Đã xác nhận' : 'Xác nhận'),
                  )
                else if (onDetails != null)
                  TextButton(
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Chi tiết'),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetaRow(
                  icon: Icons.watch_outlined,
                  text: deviceLabel ?? (alert.deviceId ?? 'Không rõ thiết bị'),
                ),
                _MetaRow(
                  icon: Icons.schedule_rounded,
                  text: DateFormat('HH:mm • dd/MM/yyyy').format(alert.createdAt.toLocal()),
                ),
                StatusBadge(
                  label: alert.acknowledged ? 'Đã xử lý' : 'Chưa xử lý',
                  tone: alert.acknowledged ? StatusTone.success : StatusTone.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Chi tiết',
                    onPressed: onDetails,
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ),
                if (canAcknowledge) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: alert.acknowledged ? 'Đã xác nhận' : 'Xác nhận',
                      onPressed: alert.acknowledged ? null : onAcknowledge,
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _severityLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
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

  StatusTone _severityTone(String raw) {
    switch (raw.trim().toLowerCase()) {
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

  Color _severityColor(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'high':
      case 'critical':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _severityIcon(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'low':
        return Icons.check_circle_outline_rounded;
      case 'medium':
        return Icons.warning_amber_rounded;
      case 'high':
      case 'critical':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
