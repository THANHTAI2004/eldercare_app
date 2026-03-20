import 'package:flutter/material.dart';

enum AppLayoutSize { compact, medium, expanded }

class AppLayout {
  AppLayout._();

  static AppLayoutSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static AppLayoutSize fromWidth(double width) {
    if (width >= 1200) return AppLayoutSize.expanded;
    if (width >= 700) return AppLayoutSize.medium;
    return AppLayoutSize.compact;
  }

  static bool isCompact(BuildContext context) {
    return of(context) == AppLayoutSize.compact;
  }

  static bool isExpanded(BuildContext context) {
    return of(context) == AppLayoutSize.expanded;
  }

  static double maxContentWidth(BuildContext context, {double? override}) {
    if (override != null) return override;

    switch (of(context)) {
      case AppLayoutSize.compact:
        return double.infinity;
      case AppLayoutSize.medium:
        return 960;
      case AppLayoutSize.expanded:
        return 1320;
    }
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double compact = 12,
    double medium = 20,
    double expanded = 24,
    double bottom = 20,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final horizontal = switch (of(context)) {
      AppLayoutSize.compact => compact,
      AppLayoutSize.medium => medium,
      AppLayoutSize.expanded => expanded,
    };

    return EdgeInsets.fromLTRB(
      horizontal,
      horizontal,
      horizontal,
      mediaQuery.padding.bottom + bottom,
    );
  }
}
