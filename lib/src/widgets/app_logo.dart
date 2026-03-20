import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 6),
              color: scheme.primary.withValues(alpha: 0.22),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.favorite_rounded,
              size: size * 0.55,
              color: scheme.onPrimary,
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _EcgPainter(
                  color: scheme.onPrimary.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final baseline = height * 0.70;

    final path = Path()
      ..moveTo(width * 0.18, baseline)
      ..lineTo(width * 0.34, baseline)
      ..lineTo(width * 0.40, height * 0.56)
      ..lineTo(width * 0.46, height * 0.84)
      ..lineTo(width * 0.54, height * 0.48)
      ..lineTo(width * 0.62, baseline)
      ..lineTo(width * 0.82, baseline);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) => false;
}
