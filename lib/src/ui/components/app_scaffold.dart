import 'package:flutter/material.dart';

import 'package:eldercare_app/src/core/app_layout.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.leading,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final pagePadding = AppLayout.pagePadding(
      context,
      compact: 16,
      medium: 24,
      expanded: 32,
      bottom: 20,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              Color(0xFFF3F9FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            const _AmbientBackground(),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppLayout.maxContentWidth(context),
                  ),
                  child: Padding(
                    padding: pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (leading != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.md),
                                child: leading!,
                              ),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  if (subtitle != null &&
                                      subtitle!.trim().isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      subtitle!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(width: AppSpacing.md),
                              Wrap(spacing: 8, children: actions),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _Glow(
              size: 220,
              color: AppColors.backgroundGlowTop.withValues(alpha: 0.8),
            ),
          ),
          Positioned(
            left: -100,
            top: 120,
            child: _Glow(
              size: 240,
              color: AppColors.backgroundGlowBottom.withValues(alpha: 0.55),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: _Glow(
              size: 280,
              color: AppColors.backgroundGlowTop.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
