import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_radius.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class SummaryStatCard extends StatelessWidget {
  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = StatusTone.neutral,
    this.subtitle,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusTone tone;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    final content = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: compact ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
          textAlign: compact ? TextAlign.center : TextAlign.left,
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: compact ? TextAlign.center : TextAlign.left,
          ),
        ],
      ],
    );

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      borderColor: color.withValues(alpha: 0.2),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: AppSpacing.sm),
                content,
              ],
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: content),
              ],
            ),
    );
  }
}

Color _toneColor(StatusTone tone) {
  switch (tone) {
    case StatusTone.info:
      return AppColors.info;
    case StatusTone.success:
      return AppColors.success;
    case StatusTone.warning:
      return AppColors.warning;
    case StatusTone.danger:
      return AppColors.danger;
    case StatusTone.neutral:
      return AppColors.textSecondary;
  }
}
