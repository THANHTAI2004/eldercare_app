import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.message = 'Đang tải dữ liệu...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
