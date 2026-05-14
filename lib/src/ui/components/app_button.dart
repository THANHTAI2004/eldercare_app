import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final Widget? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading || onPressed == null ? null : () => onPressed!.call(),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (icon ?? const SizedBox.shrink()),
      label: Text(label),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed == null ? null : () => onPressed!.call(),
      icon: icon ?? const SizedBox.shrink(),
      label: Text(label),
    );
  }
}

class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed == null ? null : () => onPressed!.call(),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      icon: icon ?? const SizedBox.shrink(),
      label: Text(label),
    );
  }
}
