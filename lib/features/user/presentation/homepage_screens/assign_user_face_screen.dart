import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/face/face_detection_util.dart';
import 'package:flutter_worksmart_app/features/user/logic/assign_user_face_logic.dart';

class RegisterFaceScanScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const RegisterFaceScanScreen({super.key, this.loginData});

  @override
  State<RegisterFaceScanScreen> createState() => _RegisterFaceScanScreenState();
}

class _RegisterFaceScanScreenState extends RegisterFaceLogic {
  String? _lastFaceClearanceMessage;
  bool _faceQualityPassed = false;
  bool _hasAcceptedPreScanGuide = false;
  bool _showCaptureFeedback = false;
  bool _showSuccessSplash = false;
  bool _completionFlowRunning = false;
  int _lastSeenCapturedCount = 0;
  Timer? _captureFeedbackTimer;
  Timer? _validationLoopTimer;
  bool _validationTickRunning = false;
  DateTime? _greenSince;
  static const Duration _greenHoldDuration = Duration(seconds: 3);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureValidationLoop();
      return;
    }

    _stopValidationLoop();
  }

  @override
  void dispose() {
    _captureFeedbackTimer?.cancel();
    _stopValidationLoop();
    super.dispose();
  }

  @override
  Future<void> onFaceRegistrationCompleted() async {
    if (!mounted || _completionFlowRunning) return;

    setState(() {
      _completionFlowRunning = true;
      _showSuccessSplash = false;
    });

    _stopRealtimeWorkAfterSuccess();

    if (!mounted) return;

    final String? faceImageUrl = latestCapturedFaceImageUrl;
    final bool shouldOfferProfilePrompt = await shouldOfferFaceAsProfileImage();

    if (!mounted) return;

    if (faceImageUrl != null && shouldOfferProfilePrompt) {
      final String? result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.tr('profile_photo_option_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        faceImageUrl,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppStrings.tr('profile_photo_option_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop('crop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppStrings.tr('crop_and_use_profile')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop('cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppStrings.tr('cancel')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      if (result == 'crop') {
        await applyRegisteredFaceAsProfileImage(faceImageUrl);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr('profile_photo_updated')),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }

    try {
      await returnToHomepage();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _completionFlowRunning = false;
        _showSuccessSplash = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _stopRealtimeWorkAfterSuccess() {
    _stopValidationLoop();
    _captureFeedbackTimer?.cancel();
    timer?.cancel();

    _greenSince = null;
    isUploadingFaceSample = false;
    isApprovingFace = false;

    final activeController = controller;
    if (activeController != null && activeController.value.isInitialized) {
      activeController.pausePreview().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncCaptureFeedback();
    _ensureValidationLoop();

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.black,
      appBar: _buildMinimalAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isCameraInitialized && controller != null)
            _buildCameraWithFaceDetection(controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (countdown > 0)
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                  border: Border.all(color: Colors.white30, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
          if (_showCaptureFeedback)
            IgnorePointer(child: _buildCaptureFeedbackOverlay()),
          if (_showSuccessSplash)
            IgnorePointer(child: _buildSuccessSplashOverlay()),
          SafeArea(
            child: Column(children: [const Spacer(), _buildFeedbackPanel()]),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraWithFaceDetection(CameraController controller) {
    return CameraPreview(controller);
  }

  void _ensureValidationLoop() {
    if (!_hasAcceptedPreScanGuide ||
        _completionFlowRunning ||
        !isCameraInitialized ||
        controller == null ||
        _validationLoopTimer != null) {
      return;
    }

    _validationLoopTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _runValidationTick(),
    );
    _runValidationTick();
  }

  void _stopValidationLoop() {
    _validationLoopTimer?.cancel();
    _validationLoopTimer = null;
    _validationTickRunning = false;
  }

  Future<void> _runValidationTick() async {
    if (!mounted ||
        _validationTickRunning ||
        _completionFlowRunning ||
        !_hasAcceptedPreScanGuide ||
        isCaptureBusy ||
        currentPhotoCount >= totalRequired ||
        controller == null ||
        !controller!.value.isInitialized) {
      return;
    }

    _validationTickRunning = true;
    try {
      await _validateFaceAndAutoCapture(controller!);
    } finally {
      _validationTickRunning = false;
    }
  }

  Future<void> _validateFaceAndAutoCapture(CameraController controller) async {
    if (_completionFlowRunning ||
        isCaptureBusy ||
        currentPhotoCount >= totalRequired) {
      return;
    }

    try {
      final XFile imageFile = await controller.takePicture();
      final faces = await FaceDetectionUtil.detectFacesInImage(imageFile);

      if (faces.isEmpty) {
        _greenSince = null;
        setState(() {
          _lastFaceClearanceMessage = AppStrings.tr('no_face_detected');
          _faceQualityPassed = false;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        return;
      }

      final face = faces.first;
      final imageSize = await FaceDetectionUtil.getImageSize(imageFile);

      // Validate face quality using utility
      final validationError = await FaceDetectionUtil.validateFaceQuality(
        face,
        imageSize,
      );

      if (validationError != null) {
        _greenSince = null;
        setState(() {
          _lastFaceClearanceMessage = AppStrings.tr(validationError);
          _faceQualityPassed = false;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        return;
      }

      // All checks passed - auto-capture
      setState(() {
        _lastFaceClearanceMessage = AppStrings.tr('face_quality_ok');
        _faceQualityPassed = true;
      });

      _greenSince ??= DateTime.now();
      final heldLongEnough =
          DateTime.now().difference(_greenSince!) >= _greenHoldDuration;

      // Capture only after face stays green continuously for a short hold.
      if (heldLongEnough &&
          !isCaptureBusy &&
          currentPhotoCount < totalRequired) {
        _greenSince = null;
        await takePhoto();
      }
    } catch (e) {
      debugPrint('Face validation error: $e');
    }
  }

  PreferredSizeWidget _buildMinimalAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        AppStrings.tr('face_training_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white24,
            shape: const CircleBorder(),
          ),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        if (isChangingLanguage)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: toggleLanguage,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                LanguageManager().locale.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedbackPanel() {
    if (!_hasAcceptedPreScanGuide) {
      return _buildPreScanGuidePanel();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isCaptureBusy
                      ? Colors.orange
                      : _faceQualityPassed
                      ? Colors.green
                      : Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _buildScanStatusLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_lastFaceClearanceMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _faceQualityPassed
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _faceQualityPassed ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                _lastFaceClearanceMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _faceQualityPassed ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_buildProgressPercentage()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: Colors.white12),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(
                      begin: 0,
                      end: _buildTrainingProgressValue(),
                    ),
                    builder: (context, animatedValue, child) {
                      return FractionallySizedBox(
                        widthFactor: animatedValue.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreScanGuidePanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.82),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Text(
            AppStrings.tr('before_scanning_title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.tr('before_scanning_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildGuideImage(
                  imagePath: AppImg.takeofGlasses,
                  label: AppStrings.tr('guide_remove_glasses'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildGuideImage(
                  imagePath: AppImg.nohatandmask,
                  label: AppStrings.tr('guide_no_hat_mask'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _hasAcceptedPreScanGuide = true;
                  _lastFaceClearanceMessage = null;
                  _faceQualityPassed = false;
                  _greenSince = null;
                });
                _ensureValidationLoop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppStrings.tr('start_scanning_acknowledge'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideImage({required String imagePath, required String label}) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1.2,
            child: Container(
              color: Colors.white10,
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
              border: Border.all(color: Colors.white70, width: 2),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(painter: _GuideGridPainter()),
            ),
          ),
        ],
      ),
    );
  }

  void _syncCaptureFeedback() {
    if (_completionFlowRunning) return;

    if (currentPhotoCount <= _lastSeenCapturedCount) return;

    final int newCount = currentPhotoCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || newCount <= _lastSeenCapturedCount) return;
      _lastSeenCapturedCount = newCount;
      _triggerCaptureFeedback();
    });
  }

  void _triggerCaptureFeedback() {
    _captureFeedbackTimer?.cancel();
    setState(() => _showCaptureFeedback = true);

    _captureFeedbackTimer = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() => _showCaptureFeedback = false);
    });
  }

  Widget _buildCaptureFeedbackOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white.withOpacity(0.18)),
        Center(
          child: Transform.translate(
            offset: const Offset(0, -36),
            child: Container(
              width: 248,
              height: 288,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.95),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessSplashOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.greenAccent.withOpacity(0.9),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 72,
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.tr('face_registered_success'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.tr('taking_you_home'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _buildTrainingProgressValue() {
    if (!_hasAcceptedPreScanGuide) {
      return 0;
    }

    if (currentPhotoCount >= totalRequired || _completionFlowRunning) {
      return 1;
    }

    if (isApprovingFace || isUploadingFaceSample || _showCaptureFeedback) {
      return 1;
    }

    if (_faceQualityPassed && _greenSince != null) {
      final double holdRatio =
          DateTime.now().difference(_greenSince!).inMilliseconds.toDouble() /
          _greenHoldDuration.inMilliseconds;
      return holdRatio.clamp(0, 1).toDouble();
    }

    return 0;
  }

  String _buildScanStatusLabel() {
    if (isApprovingFace || isUploadingFaceSample) {
      return AppStrings.tr('processing');
    }

    if (_faceQualityPassed) {
      return AppStrings.tr('face_confirmed');
    }

    return AppStrings.tr('scanning');
  }

  int _buildProgressPercentage() {
    final double progress = _buildTrainingProgressValue()
        .clamp(0, 1)
        .toDouble();
    return (progress * 100).round();
  }
}

class _GuideGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final double thirdW = size.width / 3;
    final double thirdH = size.height / 3;

    for (int i = 1; i <= 2; i++) {
      final double x = thirdW * i;
      final double y = thirdH * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
