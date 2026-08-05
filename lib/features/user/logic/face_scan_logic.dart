import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/face/face_attendance_verifier.dart';
import 'package:flutter_worksmart_app/core/util/face/face_detection_util.dart';
import 'package:flutter_worksmart_app/features/user/repository/attendance_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/attendance_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/face_scan_screen.dart';
import 'package:flutter_worksmart_app/shared/widget/common/system_loading_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class FaceScanLogic extends State<FaceScanScreen>
    with WidgetsBindingObserver {
  /// Runs the same liveness + face-match pipeline as check-in/out but never saves
  /// an attendance record — used by "Update Face" to confirm identity first.
  static const String scanTypeVerifyOnly = 'verify_face_only';

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
  Timer? _validationLoopTimer;
  bool _validationTickRunning = false;
  final AttendanceRepository _attendanceRepo = AttendanceRepository(
    AttendanceService(),
  );
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
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      if (mounted) {
        await _showCameraPermissionRequiredDialog(isPermanentlyDenied: status.isPermanentlyDenied);
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
    } else if (mounted) {
      await _showCameraInitFailedDialog();
    }
  }

  Future<void> _showCameraInitFailedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.tr('camera_unavailable_title')),
          content: Text(AppStrings.tr('camera_unavailable_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppStrings.tr('cancel_button')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                initCamera();
              },
              child: Text(AppStrings.tr('retry_action')),
            ),
          ],
        );
      },
    );
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

  Future<void> _showCameraPermissionRequiredDialog({
    required bool isPermanentlyDenied,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.tr('camera_permission_required_title')),
          content: Text(
            AppStrings.tr(
              isPermanentlyDenied
                  ? 'camera_permission_denied_scan'
                  : 'camera_permission_needed_scan',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
              child: Text(AppStrings.tr('open_settings_action')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                initCamera();
              },
              child: Text(AppStrings.tr('retry_action')),
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
        SnackBar(
          content: Text(AppStrings.tr('unable_to_resolve_user_id')),
          backgroundColor: AppColors.error,
        ),
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
        scanMessage = AppStrings.tr('face_verification_timeout');
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
          content: Text(AppStrings.tr('face_verification_timeout')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isScanning = false;
        scanProgress = 0;
        isFlashOverlayEnabled = false;
        scanMessage = AppStrings.tr('face_verification_failed_retry');
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
          content: Text(
            '${AppStrings.tr('face_verification_failed_prefix')}: $e',
          ),
          backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final bool isVerifyOnly =
        (widget.loginData?['scanType'] ?? '').toString().trim() ==
        scanTypeVerifyOnly;
    if (isVerifyOnly) {
      await _completeVerifyOnly();
      return;
    }

    final bool isCheckOut =
        (widget.loginData?['scanType'] ?? 'check_in')
            .toString()
            .trim()
            .toLowerCase() ==
        'check_out';

    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => SystemLoadingDialog(
          title:
              '${AppStrings.tr(isCheckOut ? 'check_in_title' : 'check_in_title')}...',
          subtitle: AppStrings.tr('attendance_scan_submitting'),
        ),
      );
    }

    final Map<String, dynamic>? savedRecord = await _saveAttendanceRecord(
      verification: verification.toMap(),
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

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

  Future<void> _completeVerifyOnly() async {
    if (!mounted) return;

    setState(() {
      _livenessPassedInSession = true;
      isScanning = false;
      scanProgress = 1;
      isFlashOverlayEnabled = false;
      scanMessage = 'Identity verified';
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
              Icons.verified_user_rounded,
              color: theme.colorScheme.primary,
              size: 48,
            ),
          ),
          title: Text(
            AppStrings.tr('identity_verified_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppStrings.tr('identity_verified_desc'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
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

    if (!mounted) return;
    Navigator.of(context).pop(true);
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
        SnackBar(
          content: Text(AppStrings.tr('unable_to_resolve_user_id')),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    final String workspaceId = (widget.loginData?['workspace_id'] ?? '')
        .toString()
        .trim();
    if (workspaceId.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('attendance_scan_save_failed')}: ${AppStrings.tr('unable_to_resolve_workspace')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    final String rawScanType = (widget.loginData?['scanType'] ?? 'check_in')
        .toString()
        .trim();
    final String scanType = rawScanType.toLowerCase() == 'check_out'
        ? 'check_out'
        : 'check_in';

    double latitude = 0.0;
    double longitude = 0.0;
    final dynamic rawLatLng = widget.loginData?['lat_lng'];
    if (rawLatLng is Map) {
      latitude = (rawLatLng['lat'] as num?)?.toDouble() ?? 0.0;
      longitude = (rawLatLng['lng'] as num?)?.toDouble() ?? 0.0;
    }

    // `success` already implies liveness passed — the verifier requires the
    // ordered liveness challenge before it ever reports success.
    final bool faceVerified = verification?['success'] == true;
    final bool livenessVerified = faceVerified;
    final dynamic rawSecurity = verification?['security'];
    final Map<String, dynamic> security = rawSecurity is Map
        ? Map<String, dynamic>.from(rawSecurity)
        : const <String, dynamic>{};
    final bool mockLocationDetected = security['fake_location'] == true;

    try {
      final saved = scanType == 'check_out'
          ? await _attendanceRepo.checkOut(
              workspaceId,
              latitude: latitude,
              longitude: longitude,
              faceVerified: faceVerified,
              livenessVerified: livenessVerified,
              mockLocationDetected: mockLocationDetected,
            )
          : await _attendanceRepo.checkIn(
              workspaceId,
              latitude: latitude,
              longitude: longitude,
              faceVerified: faceVerified,
              livenessVerified: livenessVerified,
              mockLocationDetected: mockLocationDetected,
            );

      final Map<String, dynamic> savedRecord = saved.toLegacyMap();
      savedRecord['uid'] = userId;
      return savedRecord;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('attendance_scan_save_failed')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }
  }
}
