import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_radius.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class MetricValueCard extends StatelessWidget {
  const MetricValueCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.tone = StatusTone.neutral,
    this.baseColor,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final StatusTone tone;
  final Color? baseColor;
  final String? subtitle;
  final FutureOr<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone, baseColor);
    final card = AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: color.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (unit.trim().isNotEmpty)
                          TextSpan(
                            text: ' $unit',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: () => onTap!.call(),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: card,
    );
  }
}

Color _toneColor(StatusTone tone, Color? baseColor) {
  switch (tone) {
    case StatusTone.info:
      return AppColors.info;
    case StatusTone.success:
      return baseColor ?? AppColors.success;
    case StatusTone.warning:
      return AppColors.warning;
    case StatusTone.danger:
      return AppColors.danger;
    case StatusTone.neutral:
      return baseColor ?? AppColors.textSecondary;
  }
}
