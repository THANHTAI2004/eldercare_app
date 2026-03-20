import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 44,
    this.showShadow = true,
  });

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.30;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F8F7A), Color(0xFF4FD5BB)],
          ),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    blurRadius: size * 0.32,
                    offset: Offset(0, size * 0.16),
                    color: const Color(0xFF0F8F7A).withValues(alpha: 0.28),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              left: size * 0.10,
              top: size * 0.10,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
            Center(
              child: Container(
                width: size * 0.72,
                height: size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: size * 0.025,
                  ),
                ),
                child: CustomPaint(
                  painter: _CareMarkPainter(
                    strokeColor: Colors.white,
                    accentColor: const Color(0xFFFFE28A),
                  ),
                ),
              ),
            ),
            Positioned(
              right: size * 0.12,
              top: size * 0.14,
              child: Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFE28A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppBrandLockup extends StatelessWidget {
  const AppBrandLockup({
    super.key,
    this.logoSize = 72,
    this.title = 'Eldercare',
    this.subtitle = 'Theo dõi sức khỏe người thân một cách rõ ràng và an tâm.',
    this.center = true,
  });

  final double logoSize;
  final String title;
  final String subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    );

    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(height: 14),
        Text(title, style: titleStyle, textAlign: center ? TextAlign.center : null),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: logoSize * 3.8),
          child: Text(
            subtitle,
            style: subtitleStyle,
            textAlign: center ? TextAlign.center : null,
          ),
        ),
      ],
    );
  }
}

class _CareMarkPainter extends CustomPainter {
  _CareMarkPainter({
    required this.strokeColor,
    required this.accentColor,
  });

  final Color strokeColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.07;

    final arcPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pulsePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.82
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final heartFill = Paint()
      ..color = strokeColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final shieldPath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.54)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.26,
        size.width * 0.50,
        size.height * 0.24,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.26,
        size.width * 0.78,
        size.height * 0.54,
      );
    canvas.drawPath(shieldPath, arcPaint);

    final heartPath = Path()
      ..moveTo(center.dx, size.height * 0.68)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.54,
        size.width * 0.28,
        size.height * 0.34,
        size.width * 0.42,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.34,
        size.width * 0.50,
        size.height * 0.40,
        size.width * 0.50,
        size.height * 0.40,
      )
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.40,
        size.width * 0.52,
        size.height * 0.34,
        size.width * 0.58,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.34,
        size.width * 0.76,
        size.height * 0.54,
        center.dx,
        size.height * 0.68,
      );
    canvas.drawPath(heartPath, heartFill);

    final pulsePath = Path()
      ..moveTo(size.width * 0.24, size.height * 0.54)
      ..lineTo(size.width * 0.36, size.height * 0.54)
      ..lineTo(size.width * 0.43, size.height * 0.46)
      ..lineTo(size.width * 0.49, size.height * 0.62)
      ..lineTo(size.width * 0.56, size.height * 0.40)
      ..lineTo(size.width * 0.63, size.height * 0.54)
      ..lineTo(size.width * 0.76, size.height * 0.54);
    canvas.drawPath(pulsePath, pulsePaint);

    final orbitPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.55;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.39),
      math.pi * 0.20,
      math.pi * 0.60,
      false,
      orbitPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CareMarkPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.accentColor != accentColor;
  }
}
