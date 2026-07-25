import 'package:flutter/material.dart';

class FaceEmbeddingLoadingDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const FaceEmbeddingLoadingDialog({
    super.key,
    this.title = 'Extracting Face Vector...',
    this.subtitle = 'Processing embeddings & syncing with server',
  });

  @override
  State<FaceEmbeddingLoadingDialog> createState() =>
      _FaceEmbeddingLoadingDialogState();
}

class _FaceEmbeddingLoadingDialogState extends State<FaceEmbeddingLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(
      begin: 0.05,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          false, // Prevents Android back button gestures during backend sync
      child: Dialog(
        backgroundColor: const Color(0xFF121824), // Dark futuristic theme
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.cyanAccent.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Laser Scan Frame
              SizedBox(
                width: 110,
                height: 110,
                child: AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _FaceScanPainter(progress: _scanAnimation.value),
                      child: Center(
                        child: Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 58,
                          color: Colors.cyanAccent.withOpacity(0.85),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Dynamic Status Message
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for standard futuristic target corners + glowing laser line
class _FaceScanPainter extends CustomPainter {
  final double progress;

  _FaceScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double cornerLength = 18.0;
    final cornerPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // 1. Draw Scanner Target Corners
    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, 0)
        ..lineTo(cornerLength, 0),
      cornerPaint,
    );
    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerLength),
      cornerPaint,
    );
    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLength)
        ..lineTo(0, size.height)
        ..lineTo(cornerLength, size.height),
      cornerPaint,
    );
    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerLength),
      cornerPaint,
    );

    // 2. Draw Moving Laser Line
    final laserY = size.height * progress;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.0),
          Colors.cyanAccent,
          Colors.cyanAccent,
          Colors.cyanAccent.withOpacity(0.0),
        ],
        stops: const [0.0, 0.25, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, laserY, size.width, 3))
      ..strokeWidth = 3.0;

    canvas.drawLine(Offset(0, laserY), Offset(size.width, laserY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceScanPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
