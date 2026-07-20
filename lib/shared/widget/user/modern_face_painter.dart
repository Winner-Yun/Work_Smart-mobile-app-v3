import 'package:flutter/material.dart';

class ModernFacePainter extends CustomPainter {
  final Color color;
  final double laserPos;

  ModernFacePainter({required this.color, required this.laserPos});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.62);
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addOval(rect)
        ..fillType = PathFillType.evenOdd,
      overlayPaint,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    double dy = center.dy + (((laserPos * 2) - 1) * radius * 0.8);
    canvas.drawLine(
      Offset(center.dx - (radius * 0.7), dy),
      Offset(center.dx + (radius * 0.7), dy),
      Paint()
        ..color = color.withOpacity(0.55)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant ModernFacePainter oldDelegate) => true;
}
