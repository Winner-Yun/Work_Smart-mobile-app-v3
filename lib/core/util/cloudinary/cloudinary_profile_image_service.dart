import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_worksmart_app/config/env.dart';
import 'package:flutter_worksmart_app/features/user/repository/config_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/config_service.dart';
import 'package:http/http.dart' as http;

class _CloudinaryCredentials {
  final String cloudName;
  final String apiKey;
  final String apiSecret;

  const _CloudinaryCredentials({
    required this.cloudName,
    required this.apiKey,
    required this.apiSecret,
  });
}

class CloudinaryProfileImageService {
  static const String _profileFolder = 'worksmart/profile_images';
  static const String _stableProfilePublicId = 'profile';
  static const String _faceFolder = 'worksmart/face_images';
  static const String _stableFacePublicIdPrefix = 'face';

  final ConfigRepository _configRepo;

  CloudinaryProfileImageService({ConfigRepository? configRepo})
    : _configRepo = configRepo ?? ConfigRepository(ConfigService());

  /// `cdn_api_key`/`cdn_api_secret` are never cached on-device (see
  /// AuthLogic._fetchAndCacheAppConfig), so every upload/delete re-fetches
  /// `/config/data` live. Falls back to `.env` (if present) only if that
  /// live fetch itself fails, so uploads degrade gracefully instead of
  /// hard-failing when the backend is briefly unreachable.
  Future<_CloudinaryCredentials> _resolveCredentials() async {
    try {
      final config = await _configRepo.getConfig();
      if (config.cdnCloudName.isNotEmpty &&
          config.cdnApiKey.isNotEmpty &&
          config.cdnApiSecret.isNotEmpty) {
        return _CloudinaryCredentials(
          cloudName: config.cdnCloudName.trim(),
          apiKey: config.cdnApiKey.trim(),
          apiSecret: config.cdnApiSecret.trim(),
        );
      }
    } catch (_) {
      // Fall through to the .env-based fallback below.
    }

    return _CloudinaryCredentials(
      cloudName: Env.cloudinaryCloudName.trim(),
      apiKey: Env.cloudinaryApiKey.trim(),
      apiSecret: Env.cloudinaryApiSecret.trim(),
    );
  }

  Future<String> uploadProfileImage({
    required File imageFile,
    required String userId,
    String? previousImageUrl,
  }) async {
    final _CloudinaryCredentials creds = await _resolveCredentials();
    final String cloudName = creds.cloudName;
    final String apiKey = creds.apiKey;
    final String apiSecret = creds.apiSecret;
    final String normalizedUserId = _normalizeUserIdSegment(userId);
    final String folder = '$_profileFolder/$normalizedUserId';
    final String expectedPublicId = '$folder/$_stableProfilePublicId';
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const String publicId = _stableProfilePublicId;

    if (cloudName.isEmpty) {
      throw Exception('Cloudinary cloud name is missing.');
    }
    if (apiKey.isEmpty) {
      throw Exception('Cloudinary API key is missing.');
    }
    if (apiSecret.isEmpty) {
      throw Exception('Cloudinary API secret is missing.');
    }

    final Uri url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final String signature = _generateSignature(
      params: <String, String>{
        'folder': folder,
        'overwrite': 'true',
        'public_id': publicId,
        'timestamp': timestamp.toString(),
      },
      apiSecret: apiSecret,
    );

    final String? oldPublicId = _extractPublicIdFromCloudinaryUrl(
      previousImageUrl,
      cloudName: cloudName,
    );

    if (oldPublicId != null &&
        oldPublicId.startsWith('$_profileFolder/') &&
        oldPublicId != expectedPublicId) {
      await _deleteImageByPublicId(
        cloudName: cloudName,
        apiKey: apiKey,
        apiSecret: apiSecret,
        publicId: oldPublicId,
      );
    }

    final request = http.MultipartRequest('POST', url)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..fields['overwrite'] = 'true';

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final String body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      String message =
          'Cloudinary upload failed (${streamedResponse.statusCode}).';
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final String? cloudinaryMessage = error['message']?.toString();
          if (cloudinaryMessage != null &&
              cloudinaryMessage.trim().isNotEmpty) {
            message = cloudinaryMessage;
          }
        }
      } catch (_) {
        // Ignore parse issues and keep generic error.
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final String? secureUrl = decoded['secure_url']?.toString();
    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw Exception('Cloudinary response missing secure_url.');
    }

    return secureUrl;
  }

  Future<String> uploadFaceSampleImage({
    required File imageFile,
    required String userId,
    required int sampleIndex,
    String? previousImageUrl,
  }) async {
    final _CloudinaryCredentials creds = await _resolveCredentials();
    final String cloudName = creds.cloudName;
    final String apiKey = creds.apiKey;
    final String apiSecret = creds.apiSecret;
    final String normalizedUserId = _normalizeUserIdSegment(userId);
    final String folder = '$_faceFolder/$normalizedUserId';
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String publicId = '$_stableFacePublicIdPrefix$sampleIndex';
    final String expectedPublicId = '$folder/$publicId';

    if (cloudName.isEmpty) {
      throw Exception('Cloudinary cloud name is missing.');
    }
    if (apiKey.isEmpty) {
      throw Exception('Cloudinary API key is missing.');
    }
    if (apiSecret.isEmpty) {
      throw Exception('Cloudinary API secret is missing.');
    }

    final Uri url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final String signature = _generateSignature(
      params: <String, String>{
        'folder': folder,
        'overwrite': 'true',
        'public_id': publicId,
        'timestamp': timestamp.toString(),
      },
      apiSecret: apiSecret,
    );

    final String? oldPublicId = _extractPublicIdFromCloudinaryUrl(
      previousImageUrl,
      cloudName: cloudName,
    );

    if (oldPublicId != null &&
        oldPublicId.startsWith('$_faceFolder/') &&
        oldPublicId != expectedPublicId) {
      await _deleteImageByPublicId(
        cloudName: cloudName,
        apiKey: apiKey,
        apiSecret: apiSecret,
        publicId: oldPublicId,
      );
    }

    final request = http.MultipartRequest('POST', url)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..fields['overwrite'] = 'true';

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final String body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      String message =
          'Cloudinary upload failed (${streamedResponse.statusCode}).';
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final String? cloudinaryMessage = error['message']?.toString();
          if (cloudinaryMessage != null &&
              cloudinaryMessage.trim().isNotEmpty) {
            message = cloudinaryMessage;
          }
        }
      } catch (_) {
        // Ignore parse issues and keep generic error.
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final String? secureUrl = decoded['secure_url']?.toString();
    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw Exception('Cloudinary response missing secure_url.');
    }

    return secureUrl;
  }

  String _generateSignature({
    required Map<String, String> params,
    required String apiSecret,
  }) {
    final entries = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final String toSign =
        '${entries.map((e) => '${e.key}=${e.value}').join('&')}$apiSecret';
    return sha1.convert(utf8.encode(toSign)).toString();
  }

  String _normalizeUserIdSegment(String userId) {
    final String normalized = userId.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    return normalized.isEmpty ? 'unknown_user' : normalized;
  }

  String? _extractPublicIdFromCloudinaryUrl(
    String? imageUrl, {
    required String cloudName,
  }) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(imageUrl.trim());
    if (uri == null) {
      return null;
    }

    final String path = uri.path;
    final String marker = '/$cloudName/image/upload/';
    final int markerIndex = path.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }

    final String tail = path.substring(markerIndex + marker.length);
    final List<String> segments = tail
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return null;
    }

    final int versionIndex = segments.indexWhere(
      (segment) => RegExp(r'^v\d+$').hasMatch(segment),
    );

    if (versionIndex < 0 || versionIndex + 1 >= segments.length) {
      return null;
    }

    final String publicIdWithExt = segments.sublist(versionIndex + 1).join('/');
    final String publicId = publicIdWithExt.replaceFirst(
      RegExp(r'\.[^./]+$'),
      '',
    );

    return publicId.trim().isEmpty ? null : publicId;
  }

  Future<void> _deleteImageByPublicId({
    required String cloudName,
    required String apiKey,
    required String apiSecret,
    required String publicId,
  }) async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String signature = _generateSignature(
      params: <String, String>{
        'public_id': publicId,
        'timestamp': timestamp.toString(),
      },
      apiSecret: apiSecret,
    );

    final Uri destroyUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/destroy',
    );

    try {
      await http.post(
        destroyUrl,
        body: <String, String>{
          'api_key': apiKey,
          'public_id': publicId,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );
    } catch (_) {
      // Best-effort cleanup. Upload should continue even if delete fails.
    }
  }
}
