import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/default_profile_urls.dart';
import 'package:flutter_worksmart_app/core/util/cloudinary/cloudinary_profile_image_service.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/device/device_info_helper.dart';
import 'package:flutter_worksmart_app/core/util/face/face_attendance_verifier.dart';
import 'package:flutter_worksmart_app/core/util/face/face_detection_util.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/assign_user_face_screen.dart';
// Import the newly created Repository and Service
import 'package:flutter_worksmart_app/features/user/repository/face_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/profile_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/face_service.dart';
import 'package:flutter_worksmart_app/features/user/service/profile_service.dart';
import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/system_loading_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class RegisterFaceLogic extends State<RegisterFaceScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool isCameraInitialized = false;
  bool isChangingLanguage = false;
  bool isBackCamera = false;
  bool isFlashOn = false;
  int currentPhotoCount = 0;
  final int totalRequired = 1;
  int countdown = 0;
  Timer? timer;
  late AnimationController laserController;
  bool isUploadingFaceSample = false;
  bool isApprovingFace = false;

  // Use the new FaceRepository for API connection[cite: 6]
  final FaceRepository _faceRepository = FaceRepository(FaceService());
  final ProfileRepository _profileRepository = ProfileRepository(
    ProfileService(),
  );

  final CloudinaryProfileImageService _cloudinaryProfileImageService =
      CloudinaryProfileImageService();
  final List<String> _capturedFaceImageUrls = <String>[];
  final List<List<double>> _capturedEmbeddings = <List<double>>[];
  String? _lastCapturedFaceFilePath;
  late final FaceAttendanceVerifier _faceAttendanceVerifier;

  String? get latestCapturedFaceImageUrl =>
      _capturedFaceImageUrls.isNotEmpty ? _capturedFaceImageUrls.first : null;

  bool get isCaptureBusy =>
      countdown > 0 || isUploadingFaceSample || isApprovingFace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
    laserController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _faceAttendanceVerifier = FaceAttendanceVerifier();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    laserController.dispose();
    timer?.cancel();
    _faceAttendanceVerifier.close();
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
    if (cameras.isNotEmpty) {
      await startCamera(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        ),
      );
    }
  }

  Future<void> startCamera(CameraDescription desc) async {
    if (controller != null) {
      await controller!.dispose();
      controller = null;
    }
    if (mounted) setState(() => isCameraInitialized = false);

    // Immediately after another screen (e.g. the face-verify step) releases
    // the camera, the hardware can briefly report "busy" while it tears
    // down. Retry with backoff instead of failing silently and leaving the
    // screen stuck on its loading spinner forever.
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final CameraController candidate = CameraController(
        desc,
        ResolutionPreset.high,
        enableAudio: false,
      );
      try {
        await candidate.initialize();
        if (!mounted) {
          await candidate.dispose();
          return;
        }
        controller = candidate;
        isBackCamera = desc.lensDirection == CameraLensDirection.back;
        setState(() => isCameraInitialized = true);
        return;
      } catch (e) {
        debugPrint(
          '[RegisterFaceLogic] Camera init attempt $attempt/$maxAttempts failed: $e',
        );
        try {
          await candidate.dispose();
        } catch (_) {}

        if (attempt == maxAttempts) {
          if (mounted) {
            await _showCameraInitFailedDialog();
          }
          return;
        }
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
  }

  Future<void> _showCameraInitFailedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Camera Unavailable'),
          content: const Text(
            'Unable to start the camera. It may still be in use by another '
            'part of the app. Please try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                initCamera();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
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

  Future<void> toggleCamera() async {
    if (cameras.isEmpty) return;
    final newDesc = isBackCamera
        ? cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
          )
        : cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
          );
    setState(() => isCameraInitialized = false);
    await startCamera(newDesc);
  }

  Future<void> toggleFlash() async {
    if (controller == null || !isBackCamera) return;
    isFlashOn = !isFlashOn;
    await controller!.setFlashMode(isFlashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> toggleLanguage() async {
    setState(() => isChangingLanguage = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final current = LanguageManager().locale;
    await LanguageManager().changeLanguage(current == 'en' ? 'km' : 'en');
    if (mounted) setState(() => isChangingLanguage = false);
  }

  void startCaptureProcess() {
    if (isCaptureBusy || currentPhotoCount >= totalRequired) return;
    setState(() => countdown = 3);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown > 1) {
        setState(() => countdown--);
      } else {
        timer?.cancel();
        setState(() => countdown = 0);
        takePhoto();
      }
    });
  }

  Future<void> takePhoto() async {
    if (controller == null ||
        !controller!.value.isInitialized ||
        isCaptureBusy) {
      return;
    }

    final String userId = _resolveUserId();
    if (userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('unable_to_resolve_user_id'))),
      );
      return;
    }

    setState(() => isUploadingFaceSample = true);

    try {
      final XFile captured = await controller!.takePicture();

      final capturedFaces = await FaceDetectionUtil.detectFacesInImage(
        captured,
      );
      if (capturedFaces.isEmpty) {
        throw Exception(AppStrings.tr('no_face_detected'));
      }
      final capturedImageSize = await FaceDetectionUtil.getImageSize(captured);

      final capturedValidationError =
          await FaceDetectionUtil.validateFaceQuality(
            capturedFaces.first,
            capturedImageSize,
          );
      if (capturedValidationError != null) {
        throw Exception(AppStrings.tr(capturedValidationError));
      }

      final List<double>? embedding = await _faceAttendanceVerifier
          .extractEmbeddingFromPath(captured.path);
      if (embedding == null) {
        throw Exception(
          'Face alignment failed. Keep your head straight and retry.',
        );
      }
      if (embedding.length != FaceAttendanceVerifier.embeddingSize) {
        throw Exception(
          'Invalid face embedding length: ${embedding.length}. Please retry.',
        );
      }

      // We still upload to Cloudinary to offer the "Set Profile Photo"
      final String imageUrl = await _cloudinaryProfileImageService
          .uploadFaceSampleImage(
            imageFile: File(captured.path),
            userId: userId,
            sampleIndex: currentPhotoCount + 1,
            previousImageUrl: null,
          );

      _lastCapturedFaceFilePath = captured.path;

      _capturedFaceImageUrls
        ..clear()
        ..add(imageUrl);

      // Store the raw embedding array[cite: 6]
      _capturedEmbeddings
        ..clear()
        ..add(embedding);

      if (!mounted) return;

      setState(() {
        if (currentPhotoCount < totalRequired) currentPhotoCount++;
      });

      if (currentPhotoCount == totalRequired) {
        await onComplete();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('face_sample_upload_failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isUploadingFaceSample = false);
      }
    }
  }

  Future<void> onComplete() async {
    if (_capturedEmbeddings.isEmpty) return;

    try {
      final List<double> embeddingVector = _capturedEmbeddings.first;

      if (embeddingVector.isEmpty) {
        throw Exception(
          'Missing face embedding. Please capture the face again.',
        );
      }

      // 1. Show the loading dialog before starting the data transfer
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const SystemLoadingDialog(
          title: 'Processing Face Vector...',
          subtitle: 'Extracting embeddings & syncing with server',
        ),
      );

      // 2. Call the API via the new Repository
      await _faceRepository.registerFace(embeddingVector);

      // 3. Cache the same embedding locally so the homepage/scan flow can see
      // it immediately, without waiting on a separate server round-trip.
      final String userId = _resolveUserId();
      if (userId.isNotEmpty) {
        try {
          final String deviceInfo =
              await DeviceInfoHelper.describeCurrentDevice();
          await DatabaseHelper().saveFaceEmbeddingWithHistory(userId, {
            'face_embeddings': embeddingVector,
          }, deviceInfo: deviceInfo);
          debugPrint(
            '[RegisterFaceLogic] Saved face embedding to local DB for $userId',
          );
        } catch (e) {
          debugPrint(
            '[RegisterFaceLogic] Failed to cache embedding locally: $e',
          );
        }
      }

      // 4. Dismiss the dialog once the backend processing is complete
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      await onFaceRegistrationCompleted();
    } catch (e) {
      // Ensure the dialog is dismissed if an error occurs
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      // Clean exception prefix for UI display
      final cleanError = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('face_sample_upload_failed')}: $cleanError',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _resolveUserId() {
    return (widget.loginData?['uid'] ?? '').toString().trim();
  }

  Future<void> returnToHomepage() async {
    if (!mounted) return;
    final Map<String, dynamic> homeArgs = Map<String, dynamic>.from(
      widget.loginData ?? <String, dynamic>{},
    )..['initialIndex'] = 0;

    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoute.appmain,
      (route) => false,
      arguments: homeArgs,
    );
  }

  Future<void> onFaceRegistrationCompleted() async {
    await returnToHomepage();
  }

  Future<bool> shouldOfferFaceAsProfileImage() async {
    final String userId = _resolveUserId();
    if (userId.isEmpty) {
      return false;
    }

    try {
      final UserModel userModel = await UserRepository(
        UserService(),
      ).getUserProfile();
      final String currentProfileUrl = userModel.avatar.trim();

      if (currentProfileUrl.isEmpty) {
        return true;
      }

      final String gender = userModel.gender.isNotEmpty
          ? userModel.gender
          : (widget.loginData?['gender'] ?? '').toString();

      final Set<String> defaultUrls = <String>{
        DefaultProfileUrls.male,
        DefaultProfileUrls.female,
        DefaultProfileUrls.byGender(gender),
      };

      final String normalizedCurrent = _normalizeUrlForCompare(
        currentProfileUrl,
      );
      return defaultUrls
          .map(_normalizeUrlForCompare)
          .contains(normalizedCurrent);
    } catch (_) {
      return false;
    }
  }

  Future<void> applyRegisteredFaceAsProfileImage(String imageUrl) async {
    final String? localFacePath = _lastCapturedFaceFilePath;

    if (localFacePath == null || localFacePath.trim().isEmpty) {
      return;
    }

    final File localFaceFile = File(localFacePath);
    if (!await localFaceFile.exists()) {
      return;
    }

    try {
      // Call the new backend endpoint directly with the captured file
      await _profileRepository.updateProfileImage(localFaceFile);

      debugPrint(
        '[RegisterFaceLogic] Profile image updated successfully via backend',
      );
    } catch (e) {
      debugPrint('[RegisterFaceLogic] Failed to update profile image: $e');
      rethrow;
    }
  }

  String _normalizeUrlForCompare(String url) {
    return url.trim().toLowerCase().replaceFirst(RegExp(r'/$'), '');
  }
}
