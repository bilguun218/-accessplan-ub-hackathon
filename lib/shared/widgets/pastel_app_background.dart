import 'package:flutter/material.dart';

class PastelAppBackground extends StatelessWidget {
  final Widget child;

  const PastelAppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _PastelBackdrop()),
        Positioned.fill(child: CustomPaint(painter: _MapLinePainter())),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _PastelBackdrop extends StatelessWidget {
  const _PastelBackdrop();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final longestSide = width > height ? width : height;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF2E9),
                Color(0xFFFFFCF8),
                Color(0xFFF9F7FF),
                Color(0xFFEAF3FF),
              ],
              stops: [0.0, 0.34, 0.64, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -longestSide * 0.20,
                top: -longestSide * 0.18,
                child: _SoftGlow(
                  size: longestSide * 0.48,
                  color: const Color(0xFFFFB58F),
                  opacity: 0.34,
                ),
              ),
              Positioned(
                right: -longestSide * 0.28,
                top: height * 0.11,
                child: _SoftGlow(
                  size: longestSide * 0.56,
                  color: const Color(0xFFE3B8FF),
                  opacity: 0.28,
                ),
              ),
              Positioned(
                left: -longestSide * 0.22,
                bottom: height * 0.09,
                child: _SoftGlow(
                  size: longestSide * 0.48,
                  color: const Color(0xFF9EC7FF),
                  opacity: 0.31,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SoftGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SoftGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.22),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
      ),
    );
  }
}

class _MapLinePainter extends CustomPainter {
  const _MapLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final startY = size.height * 0.70;
    final whiteLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final blueLine = Paint()
      ..color = const Color(0xFFBFD7FF).withValues(alpha: 0.30)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = -2; i < 8; i++) {
      final x = i * size.width / 5;
      final path = Path()
        ..moveTo(x, size.height + 36)
        ..quadraticBezierTo(
          x + size.width * 0.12,
          startY + 86,
          x + size.width * 0.32,
          startY + 8,
        );
      canvas.drawPath(path, i.isEven ? whiteLine : blueLine);
    }

    for (var i = 0; i < 7; i++) {
      final y = startY + i * 54;
      final path = Path()
        ..moveTo(-32, y)
        ..quadraticBezierTo(size.width * 0.32, y + 22, size.width + 40, y - 18);
      canvas.drawPath(path, i.isEven ? blueLine : whiteLine);
    }

    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route = Path()
      ..moveTo(size.width * 0.12, size.height * 0.91)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.84,
        size.width * 0.43,
        size.height * 0.89,
        size.width * 0.56,
        size.height * 0.81,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.73,
        size.width * 0.81,
        size.height * 0.84,
        size.width * 0.92,
        size.height * 0.77,
      );
    canvas.drawPath(route, routePaint);

    final pinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.86),
      13,
      pinPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.86),
      4,
      pinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapLinePainter oldDelegate) => false;
}
