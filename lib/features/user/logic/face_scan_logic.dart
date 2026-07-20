import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/face/face_attendance_verifier.dart';
import 'package:flutter_worksmart_app/core/util/face/face_detection_util.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/face_scan_screen.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class FaceScanLogic extends State<FaceScanScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  bool isRearCameraSelected = false;
  FlashMode flashMode = FlashMode.off;
  bool isScanning = false;
  double scanProgress = 0;
  Timer? _scanTimer;
  bool isFlashOverlayEnabled = false;
  String scanMessage = '';
  String? lastFaceQualityMessage;
  bool faceQualityPassed = false;
  LivenessAction? activeLivenessAction;
  final Set<LivenessAction> completedLivenessActions = <LivenessAction>{};
  bool _livenessPassedInSession = false;
  bool _livenessSuccessSnackShown = false;
  Timer? _validationLoopTimer;
  bool _validationTickRunning = false;
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();
  late final FaceAttendanceVerifier _faceAttendanceVerifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceAttendanceVerifier = FaceAttendanceVerifier();
    initCamera();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _stopValidationLoop();
    WidgetsBinding.instance.removeObserver(this);
    _faceAttendanceVerifier.close();
    controller?.dispose();
    super.dispose();
  }

  Future<void> initCamera() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      if (mounted) {
        await _showCameraPermissionRequiredDialog();
      }
      return;
    }

    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      final frontCamera = cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras!.first,
      );
      onNewCameraSelected(frontCamera);
    }
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) await controller!.dispose();

    final cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    controller = cameraController;
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() {
          isCameraInitialized = true;
          flashMode = FlashMode.off;
          isRearCameraSelected =
              cameraDescription.lensDirection == CameraLensDirection.back;
        });
        _ensureValidationLoop();
      }
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _showCameraPermissionRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
            'Camera permission is requested on the homepage. Please grant it there or open app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _ensureValidationLoop() {
    if (!isCameraInitialized ||
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
        isScanning ||
        controller == null ||
        !controller!.value.isInitialized) {
      return;
    }

    _validationTickRunning = true;
    try {
      await _validateFaceAndAutoScan(controller!);
    } finally {
      _validationTickRunning = false;
    }
  }

  Future<void> _validateFaceAndAutoScan(CameraController controller) async {
    if (isScanning) {
      return;
    }

    try {
      void resetPoseHintState() {
        activeLivenessAction = null;
        completedLivenessActions.clear();
      }

      final XFile imageFile = await controller.takePicture();
      final faces = await FaceDetectionUtil.detectFacesInImage(imageFile);

      if (faces.isEmpty) {
        setState(() {
          lastFaceQualityMessage = AppStrings.tr('no_face_detected');
          faceQualityPassed = false;
          resetPoseHintState();
        });
        await Future.delayed(const Duration(milliseconds: 800));
        return;
      }

      final face = faces.first;
      final imageSize = await FaceDetectionUtil.getImageSize(imageFile);

      // Validate face quality
      final validationError = await FaceDetectionUtil.validateFaceQuality(
        face,
        imageSize,
      );

      if (validationError != null) {
        setState(() {
          lastFaceQualityMessage = AppStrings.tr(validationError);
          faceQualityPassed = false;
          resetPoseHintState();
        });
        await Future.delayed(const Duration(milliseconds: 800));
        return;
      }

      // Face quality passed
      setState(() {
        lastFaceQualityMessage = AppStrings.tr('face_quality_ok');
        faceQualityPassed = true;
      });

      // Auto-trigger scan after good face detected
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted && !isScanning) {
        takePicture();
      }
    } catch (e) {
      debugPrint('Face validation error: $e');
    }
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.isEmpty) return;
    setState(() => isCameraInitialized = false);

    CameraLensDirection newDirection = isRearCameraSelected
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    CameraDescription newCamera = cameras!.firstWhere(
      (camera) => camera.lensDirection == newDirection,
      orElse: () => cameras!.first,
    );

    onNewCameraSelected(newCamera);
  }

  Future<void> toggleFlash() async {
    setState(() {
      flashMode = flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    });
  }

  Future<void> takePicture() async {
    if (isScanning || controller == null || !controller!.value.isInitialized) {
      return;
    }

    setState(() {
      isScanning = true;
      scanProgress = 0;
      scanMessage = 'Initializing secure scan...';
      activeLivenessAction = null;
      if (_livenessPassedInSession) {
        completedLivenessActions
          ..clear()
          ..add(LivenessAction.blink)
          ..add(LivenessAction.turnLeft)
          ..add(LivenessAction.turnRight);
      } else {
        completedLivenessActions.clear();
      }
    });

    final String userId = (widget.loginData?['uid'] ?? '').toString().trim();
    if (userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('unable_to_resolve_user_id'))),
      );
      setState(() {
        isScanning = false;
        scanProgress = 0;
      });
      return;
    }

    late final AttendanceVerificationResult verification;
    try {
      verification = await _faceAttendanceVerifier
          .verifyAttendance(
            cameraController: controller!,
            userId: userId,
            skipLivenessChallenges: _livenessPassedInSession,
            onFlashOverlay: (enabled) async {
              if (!mounted) return;
              setState(() => isFlashOverlayEnabled = enabled);
            },
            onProgress: (progress) {
              if (progress.message.toLowerCase().startsWith(
                    'liveness passed.',
                  ) &&
                  !_livenessPassedInSession) {
                _livenessPassedInSession = true;
                if (!_livenessSuccessSnackShown && mounted) {
                  _livenessSuccessSnackShown = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppStrings.tr('notvideo_passed'),
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              }

              if (!mounted) return;
              setState(() {
                scanProgress = progress.progress;
                scanMessage = progress.message;

                if (_livenessPassedInSession) {
                  activeLivenessAction = null;
                  completedLivenessActions
                    ..clear()
                    ..add(LivenessAction.blink)
                    ..add(LivenessAction.turnLeft)
                    ..add(LivenessAction.turnRight);
                  return;
                }

                final LivenessAction? nextAction = _parseLivenessAction(
                  progress.message,
                );
                if (nextAction != null) {
                  if (activeLivenessAction != null &&
                      activeLivenessAction != nextAction) {
                    completedLivenessActions.add(activeLivenessAction!);
                  }
                  activeLivenessAction = nextAction;
                }

                if (progress.progress >= 1) {
                  completedLivenessActions
                    ..add(LivenessAction.blink)
                    ..add(LivenessAction.turnLeft)
                    ..add(LivenessAction.turnRight);
                  activeLivenessAction = null;
                }
              });
            },
          )
          .timeout(const Duration(seconds: 50));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        isScanning = false;
        scanProgress = 0;
        isFlashOverlayEnabled = false;
        scanMessage = 'Face verification timed out. Please try again.';
        activeLivenessAction = null;
        if (_livenessPassedInSession) {
          completedLivenessActions
            ..clear()
            ..add(LivenessAction.blink)
            ..add(LivenessAction.turnLeft)
            ..add(LivenessAction.turnRight);
        } else {
          completedLivenessActions.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification timed out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isScanning = false;
        scanProgress = 0;
        isFlashOverlayEnabled = false;
        scanMessage = 'Face verification failed. Please retry.';
        activeLivenessAction = null;
        if (_livenessPassedInSession) {
          completedLivenessActions
            ..clear()
            ..add(LivenessAction.blink)
            ..add(LivenessAction.turnLeft)
            ..add(LivenessAction.turnRight);
        } else {
          completedLivenessActions.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Face verification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!verification.success) {
      final bool isNotUser =
          verification.message.toLowerCase().trim() ==
          AppStrings.tr('not_user');
      if (mounted) {
        setState(() {
          if (isNotUser) {
            _livenessPassedInSession = false;
            _livenessSuccessSnackShown = false;
          }
          isScanning = false;
          scanProgress = 0;
          isFlashOverlayEnabled = false;
          scanMessage = verification.message;
          activeLivenessAction = null;
          if (_livenessPassedInSession) {
            completedLivenessActions
              ..clear()
              ..add(LivenessAction.blink)
              ..add(LivenessAction.turnLeft)
              ..add(LivenessAction.turnRight);
          } else {
            completedLivenessActions.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verification.message),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final Map<String, dynamic>? savedRecord = await _saveAttendanceRecord(
      verification: verification.toMap(),
    );
    if (savedRecord == null) {
      if (mounted) {
        setState(() {
          isScanning = false;
          scanProgress = 0;
          isFlashOverlayEnabled = false;
          activeLivenessAction = null;
          if (_livenessPassedInSession) {
            completedLivenessActions
              ..clear()
              ..add(LivenessAction.blink)
              ..add(LivenessAction.turnLeft)
              ..add(LivenessAction.turnRight);
          } else {
            completedLivenessActions.clear();
          }
        });
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _livenessPassedInSession = true;
      isScanning = false;
      scanProgress = 1;
      isFlashOverlayEnabled = false;
      scanMessage = 'Verification passed';
      activeLivenessAction = null;
      completedLivenessActions
        ..clear()
        ..add(LivenessAction.blink)
        ..add(LivenessAction.turnLeft)
        ..add(LivenessAction.turnRight);
    });

    await controller?.pausePreview();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.primary,
              size: 48,
            ),
          ),
          title: Text(
            AppStrings.tr('scan_success'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppStrings.tr('face_scan_success_desc'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.of(context).pop(savedRecord);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppStrings.tr('understood'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    await controller?.resumePreview();
  }

  LivenessAction? _parseLivenessAction(String message) {
    final String normalized = message.toLowerCase();
    if (!normalized.startsWith('liveness:')) {
      return null;
    }

    if (normalized.contains('left')) {
      return LivenessAction.turnLeft;
    }
    if (normalized.contains('right')) {
      return LivenessAction.turnRight;
    }
    if (normalized.contains('blink')) {
      return LivenessAction.blink;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _saveAttendanceRecord({
    Map<String, dynamic>? verification,
  }) async {
    final String userId = (widget.loginData?['uid'] ?? '').toString().trim();
    if (userId.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('unable_to_resolve_user_id'))),
      );
      return null;
    }

    final String rawScanType = (widget.loginData?['scanType'] ?? 'check_in')
        .toString()
        .trim();
    final String scanType = rawScanType.toLowerCase() == 'check_out'
        ? 'check_out'
        : 'check_in';

    Map<String, dynamic>? latLng;
    final dynamic rawLatLng = widget.loginData?['lat_lng'];
    if (rawLatLng is Map) {
      latLng = Map<String, dynamic>.from(rawLatLng);
    }

    try {
      final savedRecord = await _realtimeDataController.saveAttendanceScan(
        uid: userId,
        scanType: scanType,
        scannedAt: DateTime.now(),
        latLng: latLng,
        verification: verification,
      );
      return savedRecord;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('attendance_scan_save_failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
}
