import 'dart:async';

import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.inlineSubtitle = false,
    this.showAccent = true,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final FutureOr<void> Function()? onAction;
  final bool inlineSubtitle;
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );

    Widget titleWidget = showAccent
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(title, style: titleStyle)),
            ],
          )
        : Text(title, style: titleStyle);

    Widget content;
    if (inlineSubtitle && hasSubtitle) {
      content = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          titleWidget,
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: inlineSubtitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Expanded(child: content),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction == null ? null : () => onAction!.call(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
