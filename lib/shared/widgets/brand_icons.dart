import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual-only placeholder for the Google "G" mark (four brand colors),
/// used on the login screen. No real Google Sign-In wiring yet.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.62;
    final ringRadius = radius - strokeWidth / 2;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Four quarter-arcs in Google's brand colors.
    paint.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(ringRect, -math.pi / 2, math.pi / 2, false, paint);
    paint.color = const Color(0xFF34A853); // green
    canvas.drawArc(ringRect, 0, math.pi / 2, false, paint);
    paint.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(ringRect, math.pi / 2, math.pi / 2, false, paint);
    paint.color = const Color(0xFFEA4335); // red
    canvas.drawArc(ringRect, math.pi, math.pi / 2, false, paint);

    // Horizontal bar of the "G", pointing to the right-center gap.
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - strokeWidth * 0.28, radius, strokeWidth * 0.56),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Placeholder for the Apple mark, using the Cupertino Apple logo glyph.
class AppleLogo extends StatelessWidget {
  const AppleLogo({super.key, this.size = 20, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.apple, size: size, color: color);
  }
}
