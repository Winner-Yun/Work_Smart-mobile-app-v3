import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/logic/face_scan_logic.dart';
import 'package:flutter_worksmart_app/shared/widget/user/face_pose_hint_strip.dart';

class FaceScanScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const FaceScanScreen({super.key, this.loginData});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends FaceScanLogic {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          if (flashMode == FlashMode.torch)
            IgnorePointer(child: _buildOutsideGridFlashOverlay()),
          if (isFlashOverlayEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.white.withOpacity(0.92)),
              ),
            ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -36),
                child: _buildCenterBorderGrid(),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildBottomPanel()],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _buildGlassButton(
          icon: Icons.close,
          onTap: () => Navigator.pop(context),
        ),
      ),
      centerTitle: true,
      title: Text(
        AppStrings.tr('face_scan_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: _buildGlassButton(
            icon: flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
            color: flashMode == FlashMode.torch ? Colors.yellow : Colors.white,
            onTap: toggleFlash,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    return (isCameraInitialized && controller != null)
        ? Center(child: CameraPreview(controller!))
        : const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FacePoseHintStrip(
            activeStep: activeLivenessAction,
            completedSteps: completedLivenessActions,
          ),
          if (lastFaceQualityMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: faceQualityPassed
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: faceQualityPassed ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                lastFaceQualityMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: faceQualityPassed ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutsideGridFlashOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double boxWidth = 240;
        const double boxHeight = 280;
        final double left = (constraints.maxWidth - boxWidth) / 2;
        final double top = (constraints.maxHeight - boxHeight) / 2 - 36;
        final Rect gridRect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _OutsideGridFlashPainter(gridRect: gridRect),
        );
      },
    );
  }

  Widget _buildCenterBorderGrid() {
    return SizedBox(
      width: 240,
      height: 280,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: faceQualityPassed ? Colors.greenAccent : Colors.white70,
                width: faceQualityPassed ? 2.4 : 1.4,
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(painter: _GuideGridPainter()),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GuideAccentPainter())),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white24,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, color: color, size: 20),
      onPressed: onTap,
    );
  }
}

class _GuideGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final double thirdW = size.width / 3;
    final double thirdH = size.height / 3;

    for (int i = 1; i <= 2; i++) {
      final double x = thirdW * i;
      final double y = thirdH * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint borderPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(24),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OutsideGridFlashPainter extends CustomPainter {
  final Rect gridRect;

  _OutsideGridFlashPainter({required this.gridRect});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint overlayPaint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final Path fullScreen = Path()..addRect(Offset.zero & size);
    final RRect cutout = RRect.fromRectAndRadius(
      gridRect,
      const Radius.circular(24),
    );
    final Path centerCutout = Path()..addRRect(cutout);
    final Path overlay = Path.combine(
      PathOperation.difference,
      fullScreen,
      centerCutout,
    );

    canvas.drawPath(overlay, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _OutsideGridFlashPainter oldDelegate) {
    return oldDelegate.gridRect != gridRect;
  }
}

class _GuideAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint accentPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final Paint cornerPaint = Paint()
      ..color = Colors.white60
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    const double headWidth = 130;
    const double headHeight = 150;
    const double cornerSize = 12;

    // Eye position indicators (two small circles)
    const double eyeRadius = 5;
    const double eyeSpacing = 35;
    const double eyeVerticalOffset = -35;

    // Left eye guide circle
    canvas.drawCircle(
      Offset(centerX - eyeSpacing, centerY + eyeVerticalOffset),
      eyeRadius,
      accentPaint,
    );

    // Right eye guide circle
    canvas.drawCircle(
      Offset(centerX + eyeSpacing, centerY + eyeVerticalOffset),
      eyeRadius,
      accentPaint,
    );

    // Chin bottom guide point
    canvas.drawCircle(
      Offset(centerX, centerY + headHeight / 2 - 6),
      4,
      accentPaint,
    );

    // Corner markers for frame alignment (top-left, top-right, bottom-left, bottom-right)
    final List<Offset> corners = [
      Offset(centerX - headWidth / 2 - 30, centerY - headHeight / 2 - 30),
      Offset(centerX + headWidth / 2 + 30, centerY - headHeight / 2 - 30),
      Offset(centerX - headWidth / 2 - 30, centerY + headHeight / 2 + 30),
      Offset(centerX + headWidth / 2 + 30, centerY + headHeight / 2 + 30),
    ];

    for (final Offset corner in corners) {
      // Horizontal line
      canvas.drawLine(
        Offset(corner.dx - cornerSize, corner.dy),
        Offset(corner.dx + cornerSize, corner.dy),
        cornerPaint,
      );
      // Vertical line
      canvas.drawLine(
        Offset(corner.dx, corner.dy - cornerSize),
        Offset(corner.dx, corner.dy + cornerSize),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
