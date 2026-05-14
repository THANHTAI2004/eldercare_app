import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_radius.dart';

enum StatusTone { neutral, info, success, warning, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _badgeColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _badgeColors(StatusTone tone) {
    switch (tone) {
      case StatusTone.info:
        return const _BadgeColors(
          background: Color(0xFFDBEAFE),
          foreground: AppColors.info,
        );
      case StatusTone.success:
        return const _BadgeColors(
          background: Color(0xFFDCFCE7),
          foreground: AppColors.success,
        );
      case StatusTone.warning:
        return const _BadgeColors(
          background: Color(0xFFFEF3C7),
          foreground: AppColors.warning,
        );
      case StatusTone.danger:
        return const _BadgeColors(
          background: Color(0xFFFEE2E2),
          foreground: AppColors.danger,
        );
      case StatusTone.neutral:
        return const _BadgeColors(
          background: Color(0xFFE2E8F0),
          foreground: AppColors.textSecondary,
        );
    }
  }
}

class _BadgeColors {
  const _BadgeColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
