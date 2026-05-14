import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final FutureOr<void> Function()? onAction;
  final String? secondaryLabel;
  final FutureOr<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, color: scheme.primary, size: 28),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(label: actionLabel!, onPressed: onAction),
            ),
          ],
          if (secondaryLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSecondaryAction == null
                    ? null
                    : () => onSecondaryAction!.call(),
                child: Text(secondaryLabel!),
              ),
          ],
        ],
      ),
    );
  }
}
