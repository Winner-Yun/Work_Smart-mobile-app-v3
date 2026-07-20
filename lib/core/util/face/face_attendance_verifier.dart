import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:ntp/ntp.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum LivenessAction { blink, turnLeft, turnRight }

/// Progress tracking for verification
class VerificationProgress {
  final String message;
  final double progress;

  const VerificationProgress({required this.message, required this.progress});
}

/// Attendance verification result
class AttendanceVerificationResult {
  final bool success;
  final String message;
  final double similarity;
  final double threshold;
  final String livenessSummary;
  final bool flashPassed;
  final Map<String, dynamic> security;

  const AttendanceVerificationResult({
    required this.success,
    required this.message,
    required this.similarity,
    required this.threshold,
    required this.livenessSummary,
    required this.flashPassed,
    required this.security,
  });

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'success': success,
      'message': message,
      'similarity': similarity,
      'threshold': threshold,
      'liveness_summary': livenessSummary,
      'flash_passed': flashPassed,
      'security': security,
      'verified_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Main attendance verification: security checks → face match → liveness
class FaceAttendanceVerifier {
  FaceAttendanceVerifier({RealtimeDataController? dataController})
    : _dataController = dataController ?? RealtimeDataController(),
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.2,
        ),
      );

  static const String modelAssetPath = 'assets/models/mobilefacenet.tflite';
  static const int embeddingSize = 192;
  static const double _livenessYawThreshold = 6;
  static const double _livenessPitchMax = 25;

  final RealtimeDataController _dataController;
  final FaceDetector _faceDetector;
  Interpreter? _interpreter;

  /// Cleanup resources
  Future<void> close() async {
    await _faceDetector.close();
    _interpreter?.close();
    _interpreter = null;
  }

  /// Verify attendance: security → face match → liveness
  Future<AttendanceVerificationResult> verifyAttendance({
    required CameraController cameraController,
    required String userId,
    required Future<void> Function(bool enabled) onFlashOverlay,
    required void Function(VerificationProgress progress) onProgress,
    bool skipLivenessChallenges = false,
  }) async {
    onProgress(
      const VerificationProgress(
        message: 'Running security checks...',
        progress: 0.05,
      ),
    );

    final Map<String, dynamic>? userRecord = await _dataController
        .fetchUserRecordById(userId);
    if (userRecord == null) {
      return _fail('User profile not found for verification.');
    }

    final Map<String, dynamic>? faceRecord = await _dataController
        .fetchUserFaceBiometrics(userId);

    /// Validate device security
    final SecurityValidationResult securityValidation = await _validateSecurity(
      userRecord: userRecord,
    );
    if (!securityValidation.passed) {
      return _fail(
        securityValidation.message,
        security: securityValidation.toMap(),
      );
    }

    onProgress(
      const VerificationProgress(
        message: 'Checking face alignment...',
        progress: 0.15,
      ),
    );

    /// Capture aligned face
    final CapturedFace? baseline = await _captureAlignedFace(cameraController);
    if (baseline == null) {
      return _fail(
        'No aligned face detected. Keep your face centered and straight.',
      );
    }

    /// Extract face embedding first
    onProgress(
      const VerificationProgress(
        message: 'Generating face embedding...',
        progress: 0.28,
      ),
    );
    final List<double>? probeEmbedding = await extractEmbeddingFromPath(
      baseline.file.path,
    );
    if (probeEmbedding == null) {
      return _fail('Failed to extract face embedding from the captured face.');
    }

    /// Match against enrolled embeddings first
    final List<List<double>> storedEmbeddings = _extractStoredEmbeddings(
      faceRecord,
    );
    if (storedEmbeddings.isEmpty) {
      return _fail(
        'No enrolled face embeddings found. Please register your face again.',
      );
    }

    onProgress(
      const VerificationProgress(
        message: 'Checking registered face match...',
        progress: 0.4,
      ),
    );

    final double similarityThreshold = _readSimilarityThreshold(faceRecord);
    final double bestSimilarity = _maxCosineSimilarity(
      probeEmbedding,
      storedEmbeddings,
    );

    /// If face mismatch, stop immediately
    if (bestSimilarity <= similarityThreshold) {
      return _fail(
        AppStrings.tr('not_user'),
        similarity: bestSimilarity,
        threshold: similarityThreshold,
        security: securityValidation.toMap(),
      );
    }

    final String matchedUserName = _resolveDisplayName(userRecord, userId);
    onProgress(
      VerificationProgress(
        message: 'Face matched: $matchedUserName. Do pose now.',
        progress: 0.5,
      ),
    );

    bool flashPassed = true;
    if (!skipLivenessChallenges) {
      /// Run liveness challenges in strict order: left -> right -> blink
      final List<LivenessAction> challenges = _orderedChallenges();
      for (int i = 0; i < challenges.length; i++) {
        final LivenessAction challenge = challenges[i];
        onProgress(
          VerificationProgress(
            message: 'Liveness: ${_labelForAction(challenge)}',
            progress: 0.58 + (i * 0.12),
          ),
        );

        final LivenessCheckResult challengeResult = await _runChallenge(
          cameraController: cameraController,
          baseline: baseline,
          challenge: challenge,
        );

        if (!challengeResult.passed) {
          return _fail(
            challengeResult.message,
            security: securityValidation.toMap(),
          );
        }
      }

      /// Anti-spoof flash check
      onProgress(
        const VerificationProgress(
          message: 'Running screen flash anti-spoof check...',
          progress: 0.9,
        ),
      );
      flashPassed = await _runFlashHeuristic(
        cameraController: cameraController,
        onFlashOverlay: onFlashOverlay,
        baseline: baseline,
      );
      if (!flashPassed) {
        return _fail(
          'Screen reflection test failed. Possible spoof detected.',
          security: securityValidation.toMap(),
        );
      }

      onProgress(
        const VerificationProgress(
          message: 'Liveness passed. You can retry face recognition directly.',
          progress: 0.96,
        ),
      );
    } else {
      onProgress(
        VerificationProgress(
          message: 'Face matched: $matchedUserName. Liveness already verified.',
          progress: 0.96,
        ),
      );
    }

    /// All checks passed - report success
    onProgress(
      const VerificationProgress(
        message: 'Verification passed.',
        progress: 1.0,
      ),
    );

    return AttendanceVerificationResult(
      success: true,
      message: 'Face verification passed for $matchedUserName.',
      similarity: bestSimilarity,
      threshold: similarityThreshold,
      livenessSummary: skipLivenessChallenges
          ? 'Liveness already verified in this session.'
          : 'Ordered liveness challenge passed (left, right, blink).',
      flashPassed: flashPassed,
      security: securityValidation.toMap(),
    );
  }

  /// Extract face embedding using MobileFaceNet
  Future<List<double>?> extractEmbeddingFromPath(String imagePath) async {
    final CapturedFace? capturedFace = await _detectSingleFaceFromPath(
      imagePath,
    );
    if (capturedFace == null) {
      return null;
    }

    final File file = File(imagePath);
    if (!file.existsSync()) {
      return null;
    }

    final img.Image? decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      return null;
    }

    /// Crop and resize face
    final Rect bounded = _clampRect(
      capturedFace.face.boundingBox,
      decoded.width,
      decoded.height,
    );
    final img.Image faceCrop = img.copyCrop(
      decoded,
      x: bounded.left.toInt(),
      y: bounded.top.toInt(),
      width: bounded.width.toInt(),
      height: bounded.height.toInt(),
    );

    final img.Image resized = img.copyResize(faceCrop, width: 112, height: 112);

    /// Normalize and create input tensor
    final List<List<List<List<double>>>> input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(112, (x) {
          final pixel = resized.getPixel(x, y);
          final double r = (pixel.r - 127.5) / 128.0;
          final double g = (pixel.g - 127.5) / 128.0;
          final double b = (pixel.b - 127.5) / 128.0;
          return <double>[r, g, b];
        }),
      ),
    );

    /// Run model and L2 normalize
    final Interpreter interpreter = await _getInterpreter();
    final List<List<double>> output = List.generate(
      1,
      (_) => List.filled(embeddingSize, 0),
    );
    interpreter.run(input, output);

    return _l2Normalize(output.first);
  }

  Future<Interpreter> _getInterpreter() async {
    if (_interpreter != null) {
      return _interpreter!;
    }

    _interpreter = await Interpreter.fromAsset(modelAssetPath);
    return _interpreter!;
  }

  /// Validate device security
  Future<SecurityValidationResult> _validateSecurity({
    required Map<String, dynamic> userRecord,
  }) async {
    bool fakeLocationDetected = false;
    bool jailbroken = false;
    bool developerMode = false;
    bool ntpValid = true;
    int ntpSkewMs = 0;

    try {
      fakeLocationDetected = await DetectFakeLocation().detectFakeLocation();
    } catch (_) {
      fakeLocationDetected = false;
    }

    try {
      jailbroken = await FlutterJailbreakDetection.jailbroken;
    } catch (_) {
      jailbroken = false;
    }

    try {
      final DateTime ntpNow = await NTP.now(
        timeout: const Duration(seconds: 3),
      );
      ntpSkewMs = ntpNow.difference(DateTime.now()).inMilliseconds.abs();
      ntpValid = ntpSkewMs <= 120000;
    } catch (_) {
      ntpValid = false;
    }

    if (fakeLocationDetected) {
      return SecurityValidationResult.failed(
        'Fake GPS was detected on this device.',
        fakeLocation: true,
        jailbroken: jailbroken,
        developerMode: developerMode,
        ntpSkewMs: ntpSkewMs,
        ntpValid: ntpValid,
        deviceBound: '',
        deviceCurrent: '',
      );
    }

    if (jailbroken) {
      return SecurityValidationResult.failed(
        'Root/Jailbreak detected. Attendance is blocked.',
        fakeLocation: false,
        jailbroken: true,
        developerMode: developerMode,
        ntpSkewMs: ntpSkewMs,
        ntpValid: ntpValid,
        deviceBound: '',
        deviceCurrent: '',
      );
    }

    if (!ntpValid) {
      return SecurityValidationResult.failed(
        'Device time is not trusted (NTP check failed).',
        fakeLocation: false,
        jailbroken: false,
        developerMode: developerMode,
        ntpSkewMs: ntpSkewMs,
        ntpValid: false,
        deviceBound: '',
        deviceCurrent: '',
      );
    }

    return SecurityValidationResult.success(
      fakeLocation: false,
      jailbroken: false,
      developerMode: false,
      ntpSkewMs: ntpSkewMs,
      ntpValid: true,
      deviceBound: '',
      deviceCurrent: '',
    );
  }

  /// Capture aligned face
  Future<CapturedFace?> _captureAlignedFace(
    CameraController cameraController,
  ) async {
    for (int i = 0; i < 5; i++) {
      final XFile file = await cameraController.takePicture();
      final CapturedFace? capturedFace = await _detectSingleFaceFromPath(
        file.path,
      );
      if (capturedFace == null) {
        continue;
      }

      final double yaw = capturedFace.face.headEulerAngleY?.abs() ?? 0;
      final double pitch = capturedFace.face.headEulerAngleX?.abs() ?? 0;
      if (yaw > 15 || pitch > 10) {
        continue;
      }

      return capturedFace;
    }
    return null;
  }

  /// Detect single face in image
  Future<CapturedFace?> _detectSingleFaceFromPath(String path) async {
    final InputImage inputImage = InputImage.fromFilePath(path);
    final List<Face> faces = await _faceDetector.processImage(inputImage);
    if (faces.length != 1) {
      return null;
    }

    return CapturedFace(file: File(path), face: faces.first);
  }

  /// Run liveness challenge
  Future<LivenessCheckResult> _runChallenge({
    required CameraController cameraController,
    required CapturedFace baseline,
    required LivenessAction challenge,
  }) async {
    final DateTime startedAt = DateTime.now();
    final double baselineEyes = _meanEyeOpen(baseline.face);

    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 450));

      // For liveness challenges, allow natural head motion and evaluate action
      // directly from a single-face capture instead of strict alignment.
      final CapturedFace? current = await _captureSingleFace(cameraController);
      if (current == null) {
        continue;
      }

      bool actionSatisfied = false;
      final double yaw = current.face.headEulerAngleY ?? 0;
      final double pitch = (current.face.headEulerAngleX ?? 0).abs();
      final double currentEyes = _meanEyeOpen(current.face);

      if (challenge == LivenessAction.blink) {
        final double leftEye =
            current.face.leftEyeOpenProbability ?? currentEyes;
        final double rightEye =
            current.face.rightEyeOpenProbability ?? currentEyes;
        final bool oneEyeClosed = leftEye <= 0.35 || rightEye <= 0.35;
        final bool bothReduced =
            currentEyes <= 0.5 && (baselineEyes - currentEyes) >= 0.2;
        actionSatisfied = oneEyeClosed || bothReduced;
      } else if (challenge == LivenessAction.turnLeft) {
        // Front camera is mirrored for users, so left/right yaw checks are swapped.
        actionSatisfied =
            yaw >= _livenessYawThreshold && pitch <= _livenessPitchMax;
      } else if (challenge == LivenessAction.turnRight) {
        actionSatisfied =
            yaw <= -_livenessYawThreshold && pitch <= _livenessPitchMax;
      }

      if (!actionSatisfied) {
        continue;
      }

      final int reactionMs = DateTime.now()
          .difference(startedAt)
          .inMilliseconds;
      if (reactionMs < 200) {
        return const LivenessCheckResult(
          passed: false,
          message: 'Liveness challenge completed too quickly. Spoof suspected.',
        );
      }

      return const LivenessCheckResult(
        passed: true,
        message: 'Liveness challenge passed.',
      );
    }

    return LivenessCheckResult(
      passed: false,
      message: 'Failed liveness challenge: ${_labelForAction(challenge)}.',
    );
  }

  /// Capture a single-face frame without strict pose constraints.
  Future<CapturedFace?> _captureSingleFace(
    CameraController cameraController,
  ) async {
    for (int i = 0; i < 3; i++) {
      final XFile file = await cameraController.takePicture();
      final CapturedFace? capturedFace = await _detectSingleFaceFromPath(
        file.path,
      );
      if (capturedFace != null) {
        return capturedFace;
      }
    }
    return null;
  }

  /// Flash anti-spoof check
  Future<bool> _runFlashHeuristic({
    required CameraController cameraController,
    required Future<void> Function(bool enabled) onFlashOverlay,
    required CapturedFace baseline,
  }) async {
    final img.Image? before = img.decodeImage(
      await baseline.file.readAsBytes(),
    );
    if (before == null) {
      return false;
    }

    await onFlashOverlay(true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final CapturedFace? flashed = await _captureAlignedFace(cameraController);
    await onFlashOverlay(false);

    if (flashed == null) {
      return false;
    }

    final img.Image? after = img.decodeImage(await flashed.file.readAsBytes());
    if (after == null) {
      return false;
    }

    final BrightnessStats beforeStats = _faceBrightnessStats(
      before,
      baseline.face.boundingBox,
    );
    final BrightnessStats afterStats = _faceBrightnessStats(
      after,
      flashed.face.boundingBox,
    );

    final double avgDelta = (afterStats.mean - beforeStats.mean).abs();
    final double stdDelta = (afterStats.stdDev - beforeStats.stdDev).abs();

    return avgDelta >= 3 && avgDelta <= 80 && stdDelta <= 45;
  }

  /// Calculate brightness stats for face region
  BrightnessStats _faceBrightnessStats(img.Image image, Rect box) {
    final Rect bounded = _clampRect(box, image.width, image.height);
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = bounded.top.toInt(); y < bounded.bottom.toInt(); y++) {
      for (int x = bounded.left.toInt(); x < bounded.right.toInt(); x++) {
        final pixel = image.getPixel(x, y);
        final double gray =
            (pixel.r * 0.299) + (pixel.g * 0.587) + (pixel.b * 0.114);
        sum += gray;
        sumSq += gray * gray;
        count++;
      }
    }

    if (count == 0) {
      return const BrightnessStats(mean: 0, stdDev: 0);
    }

    final double mean = sum / count;
    final double variance = max(0, (sumSq / count) - (mean * mean));
    return BrightnessStats(mean: mean, stdDev: sqrt(variance));
  }

  /// L2 normalize embedding
  List<double> _l2Normalize(List<double> embedding) {
    final double norm = sqrt(
      embedding.fold<double>(0.0, (sum, v) => sum + (v * v)),
    );
    if (norm == 0) {
      return embedding;
    }
    return embedding.map((v) => v / norm).toList(growable: false);
  }

  /// Extract enrolled embeddings
  List<List<double>> _extractStoredEmbeddings(
    Map<String, dynamic>? faceRecord,
  ) {
    final Map<String, dynamic> enrollment = _asMap(faceRecord);
    final dynamic rawEmbeddings =
        enrollment['face_embeddings'] ??
        enrollment['face_vectors'] ??
        enrollment['face_embedding_vector'];
    if (rawEmbeddings is! List) {
      return <List<double>>[];
    }

    if (rawEmbeddings.isNotEmpty &&
        rawEmbeddings.every((entry) => entry is num)) {
      final List<double> values = rawEmbeddings
          .whereType<num>()
          .map((v) => v.toDouble())
          .toList(growable: false);
      final double scale = _readEmbeddingScale(enrollment);
      final List<double> normalized = scale > 0 && (scale - 1).abs() > 1e-9
          ? values.map((value) => value / scale).toList(growable: false)
          : values;
      return normalized.length == embeddingSize
          ? <List<double>>[normalized]
          : <List<double>>[];
    }

    return rawEmbeddings
        .map((entry) {
          if (entry is List) {
            return entry
                .whereType<num>()
                .map((v) => v.toDouble())
                .toList(growable: false);
          }

          if (entry is Map) {
            final dynamic rawVector =
                entry['vector'] ?? entry['embedding'] ?? entry['values'];
            if (rawVector is List) {
              final List<double> values = rawVector
                  .whereType<num>()
                  .map((v) => v.toDouble())
                  .toList(growable: false);

              final dynamic rawScale = entry['scale'];
              final double? scale = rawScale is num
                  ? rawScale.toDouble()
                  : double.tryParse(rawScale?.toString() ?? '');
              if (scale != null && scale > 0 && (scale - 1).abs() > 1e-9) {
                return values
                    .map((value) => value / scale)
                    .toList(growable: false);
              }

              return values;
            }
          }

          return <double>[];
        })
        .where((embedding) => embedding.length == embeddingSize)
        .toList(growable: false);
  }

  double _readEmbeddingScale(Map<String, dynamic> enrollment) {
    final dynamic rawScale =
        enrollment['face_embedding_scale'] ?? enrollment['scale'];
    return rawScale is num
        ? rawScale.toDouble()
        : double.tryParse(rawScale?.toString() ?? '') ?? 1;
  }

  /// Find max similarity
  double _maxCosineSimilarity(List<double> probe, List<List<double>> enrolled) {
    double best = -1;
    for (final List<double> candidate in enrolled) {
      final double score = _cosineSimilarity(probe, candidate);
      if (score > best) {
        best = score;
      }
    }
    return best;
  }

  /// Calculate cosine similarity
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) {
      return -1;
    }

    double dot = 0;
    double normA = 0;
    double normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) {
      return -1;
    }

    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Get similarity threshold
  double _readSimilarityThreshold(Map<String, dynamic>? faceRecord) {
    final Map<String, dynamic> enrollment = _asMap(faceRecord);
    final dynamic configured = enrollment['face_match_threshold'];
    final double threshold = configured is num ? configured.toDouble() : 0.6;
    return threshold.clamp(0.4, 0.95);
  }

  /// Fixed challenge order required by attendance flow
  List<LivenessAction> _orderedChallenges() {
    return <LivenessAction>[
      LivenessAction.turnLeft,
      LivenessAction.turnRight,
      LivenessAction.blink,
    ];
  }

  /// Label for action
  String _labelForAction(LivenessAction action) {
    switch (action) {
      case LivenessAction.blink:
        return 'Blink naturally';
      case LivenessAction.turnLeft:
        return 'Turn your head left';
      case LivenessAction.turnRight:
        return 'Turn your head right';
    }
  }

  /// Mean eye openness
  double _meanEyeOpen(Face face) {
    final double left = face.leftEyeOpenProbability ?? 0.8;
    final double right = face.rightEyeOpenProbability ?? 0.8;
    return (left + right) / 2;
  }

  /// Clamp rect to bounds
  Rect _clampRect(Rect source, int width, int height) {
    final double left = source.left.clamp(0, width - 1).toDouble();
    final double top = source.top.clamp(0, height - 1).toDouble();
    final double right = source.right
        .clamp(left + 1, width.toDouble())
        .toDouble();
    final double bottom = source.bottom
        .clamp(top + 1, height.toDouble())
        .toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _resolveDisplayName(Map<String, dynamic> userRecord, String userId) {
    const List<String> nameKeys = <String>[
      'name',
      'full_name',
      'fullName',
      'display_name',
      'displayName',
      'username',
      'user_name',
      'employee_name',
    ];

    for (final String key in nameKeys) {
      final String value = (userRecord[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return userId;
  }

  /// Failed result
  AttendanceVerificationResult _fail(
    String message, {
    double similarity = 0,
    double threshold = 0.6,
    Map<String, dynamic>? security,
  }) {
    return AttendanceVerificationResult(
      success: false,
      message: message,
      similarity: similarity,
      threshold: threshold,
      livenessSummary: 'Failed',
      flashPassed: false,
      security: security ?? <String, dynamic>{},
    );
  }
}

/// Captured face data
class CapturedFace {
  final File file;
  final Face face;

  const CapturedFace({required this.file, required this.face});
}

/// Liveness challenge result
class LivenessCheckResult {
  final bool passed;
  final String message;

  const LivenessCheckResult({required this.passed, required this.message});
}

/// Brightness stats
class BrightnessStats {
  final double mean;
  final double stdDev;

  const BrightnessStats({required this.mean, required this.stdDev});
}

/// Security validation result
class SecurityValidationResult {
  final bool passed;
  final String message;
  final bool fakeLocation;
  final bool jailbroken;
  final bool developerMode;
  final bool ntpValid;
  final int ntpSkewMs;
  final String deviceBound;
  final String deviceCurrent;

  const SecurityValidationResult._({
    required this.passed,
    required this.message,
    required this.fakeLocation,
    required this.jailbroken,
    required this.developerMode,
    required this.ntpValid,
    required this.ntpSkewMs,
    required this.deviceBound,
    required this.deviceCurrent,
  });

  factory SecurityValidationResult.success({
    required bool fakeLocation,
    required bool jailbroken,
    required bool developerMode,
    required bool ntpValid,
    required int ntpSkewMs,
    required String deviceBound,
    required String deviceCurrent,
  }) {
    return SecurityValidationResult._(
      passed: true,
      message: 'Security checks passed',
      fakeLocation: fakeLocation,
      jailbroken: jailbroken,
      developerMode: developerMode,
      ntpValid: ntpValid,
      ntpSkewMs: ntpSkewMs,
      deviceBound: deviceBound,
      deviceCurrent: deviceCurrent,
    );
  }

  factory SecurityValidationResult.failed(
    String message, {
    required bool fakeLocation,
    required bool jailbroken,
    required bool developerMode,
    required bool ntpValid,
    required int ntpSkewMs,
    required String deviceBound,
    required String deviceCurrent,
  }) {
    return SecurityValidationResult._(
      passed: false,
      message: message,
      fakeLocation: fakeLocation,
      jailbroken: jailbroken,
      developerMode: developerMode,
      ntpValid: ntpValid,
      ntpSkewMs: ntpSkewMs,
      deviceBound: deviceBound,
      deviceCurrent: deviceCurrent,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'passed': passed,
      'message': message,
      'fake_location': fakeLocation,
      'jailbroken': jailbroken,
      'developer_mode': developerMode,
      'ntp_valid': ntpValid,
      'ntp_skew_ms': ntpSkewMs,
      'bound_device_id': deviceBound,
      'current_device_id': deviceCurrent,
    };
  }
}
