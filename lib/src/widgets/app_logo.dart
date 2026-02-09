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
            // đường ECG nhỏ (nhìn “medical” hơn)
            Positioned.fill(
              child: CustomPaint(
                painter: _EcgPainter(color: scheme.onPrimary.withValues(alpha: 0.92)),
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
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final y = h * 0.70;

    final path = Path()
      ..moveTo(w * 0.18, y)
      ..lineTo(w * 0.34, y)
      ..lineTo(w * 0.40, h * 0.56)
      ..lineTo(w * 0.46, h * 0.84)
      ..lineTo(w * 0.54, h * 0.48)
      ..lineTo(w * 0.62, y)
      ..lineTo(w * 0.82, y);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) => false;
}
