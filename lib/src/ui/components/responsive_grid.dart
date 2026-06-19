import 'package:flutter/material.dart';

import 'package:eldercare_app/src/ui/app_spacing.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 260,
    this.spacing = AppSpacing.lg,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var columnCount = 1;
        if (maxWidth.isFinite && maxWidth > 0) {
          columnCount = ((maxWidth + spacing) / (minItemWidth + spacing))
              .floor()
              .clamp(1, children.length);
        }

        final itemWidth = maxWidth.isFinite
            ? (maxWidth - spacing * (columnCount - 1)) / columnCount
            : minItemWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
