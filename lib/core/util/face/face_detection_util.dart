import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Face validation helper
class FaceDetectionUtil {
  /// Validate face quality
  static Future<String?> validateFaceQuality(Face face, Size imageSize) async {
    try {
      // Head straight
      final double yaw = face.headEulerAngleY?.abs() ?? 0;
      final double pitch = face.headEulerAngleX?.abs() ?? 0;

      if (yaw > 15 || pitch > 12) {
        return 'face_not_straight';
      }

      // Face size
      final box = face.boundingBox;
      final faceArea = box.width * box.height;
      final imageArea = imageSize.width * imageSize.height;

      final ratio = faceArea / imageArea;

      if (ratio < 0.18) {
        return 'move_closer_full_face_required';
      }

      // Face centered
      final centerX = box.left + box.width / 2;
      final centerY = box.top + box.height / 2;

      final offsetX = (centerX - imageSize.width / 2).abs();
      final offsetY = (centerY - imageSize.height / 2).abs();

      if (offsetX > imageSize.width * 0.2 || offsetY > imageSize.height * 0.2) {
        return 'face_not_centered';
      }

      // Eyes clear
      final double leftOpen = face.leftEyeOpenProbability ?? 0;
      final double rightOpen = face.rightEyeOpenProbability ?? 0;

      if (leftOpen < 0.5 || rightOpen < 0.5) {
        return 'eyes_not_clear';
      }

      // Neutral expression
      final double smiling = face.smilingProbability ?? 0;
      if (smiling > 0.4) {
        return 'keep_neutral_expression';
      }

      // Lighting check
      if (detectLightPollution(face)) {
        return 'bad_lighting';
      }

      return null; // All checks passed
    } catch (e) {
      debugPrint('Face validation error: $e');
      return 'face_validation_error';
    }
  }

  /// Detect faces in image
  static Future<List<Face>> detectFacesInImage(XFile imageFile) async {
    final faceDetector = createFaceDetector();
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      return await faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Face detection error: $e');
      return <Face>[];
    } finally {
      await faceDetector.close();
    }
  }

  /// Get image size
  static Future<Size> getImageSize(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      codec.dispose();
      return size;
    } catch (e) {
      debugPrint('Image size read error: $e');
      return const Size(1080, 1920);
    }
  }

  /// Create face detector
  static FaceDetector createFaceDetector() {
    return FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        minFaceSize: 0.3,
      ),
    );
  }

  // Screen reflection detection

  /// Light check
  static bool detectLightPollution(Face face, {Size? imageSize}) {
    try {
      final leftOpen = face.leftEyeOpenProbability ?? 0.5;
      final rightOpen = face.rightEyeOpenProbability ?? 0.5;

      // Eyes too closed
      if (leftOpen < 0.08 && rightOpen < 0.08) return true;

      // Landmark spread
      final box = face.boundingBox;
      final boxW = box.width;
      final boxH = box.height;

      if (boxW <= 0 || boxH <= 0) return false;

      final validPositions = face.landmarks.values
          .where((l) => l != null)
          .map((l) => l!.position)
          .toList();

      if (validPositions.isEmpty) {
        return true;
      }

      // Compute spread
      double minLx = double.infinity, maxLx = double.negativeInfinity;
      double minLy = double.infinity, maxLy = double.negativeInfinity;

      for (final pos in validPositions) {
        final x = pos.x.toDouble();
        final y = pos.y.toDouble();
        if (x < minLx) minLx = x;
        if (x > maxLx) maxLx = x;
        if (y < minLy) minLy = y;
        if (y > maxLy) maxLy = y;
      }

      final spreadX = (maxLx - minLx) / boxW;
      final spreadY = (maxLy - minLy) / boxH;

      // Clustered landmarks
      if (validPositions.length >= 3 && spreadX < 0.12 && spreadY < 0.12) {
        return true;
      }

      // Landmark count
      final yaw = face.headEulerAngleY?.abs() ?? 0;
      final pitch = face.headEulerAngleX?.abs() ?? 0;
      final headStraight = yaw < 10 && pitch < 10;

      if (headStraight && validPositions.length < 4) {
        return true;
      }

      // Border check
      if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
        final marginX = imageSize.width * 0.05;
        final marginY = imageSize.height * 0.05;

        final allAtBorder = validPositions.every((pos) {
          final x = pos.x.toDouble();
          final y = pos.y.toDouble();
          return x < marginX ||
              x > imageSize.width - marginX ||
              y < marginY ||
              y > imageSize.height - marginY;
        });

        if (headStraight && allAtBorder && validPositions.length >= 3) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Light pollution detection error: $e');
      return false;
    }
  }
}
