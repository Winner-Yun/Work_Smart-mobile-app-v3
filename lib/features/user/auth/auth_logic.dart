// ignore_for_file: unrelated_type_equality_checks

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/repository/config_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/config_service.dart';
import 'package:flutter_worksmart_app/shared/widget/common/system_loading_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum GoogleReauthStatus { success, cancelled, emailMismatch, error }

/// Result of [AuthLogic.reauthenticateForSensitiveAction].
class GoogleReauthResult {
  final GoogleReauthStatus status;
  final String? email;

  const GoogleReauthResult(this.status, {this.email});
}

class AuthLogic {
  final BuildContext context;
  final ApiClient _apiClient;
  final DatabaseHelper _databaseHelper;
  final GoogleSignIn _googleSignIn;
  final ConfigRepository _configRepo;

  Map<String, dynamic>? _lastAuthenticatedUser;
  bool _googleSignInInitialized = false;

  AuthLogic({
    required this.context,
    ApiClient? apiClient,
    DatabaseHelper? databaseHelper,
    GoogleSignIn? googleSignIn,
    ConfigRepository? configRepo,
  }) : _apiClient = apiClient ?? ApiClient(),
       _databaseHelper = databaseHelper ?? DatabaseHelper(),
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _configRepo = configRepo ?? ConfigRepository(ConfigService());

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(
      // Configured with your Web Client ID for cross-platform stability
      clientId:
          '1056804642375-35aef034vihg833jm62c4bmtuo1vof4o.apps.googleusercontent.com',
      serverClientId:
          '1056804642375-35aef034vihg833jm62c4bmtuo1vof4o.apps.googleusercontent.com',
    );
    _googleSignInInitialized = true;
  }

  // ─────────── AUTO LOGIN (cached session) ───────────

  Future<void> checkCachedLogin(
    Function(String, String, String) onAutoLogin,
  ) async {
    final cachedLogin = await _databaseHelper.getCachedLogin();
    if (cachedLogin == null) return;

    final username = (cachedLogin['username'] ?? '').toString();
    final userId = (cachedLogin['user_id'] ?? '').toString();
    final userType = (cachedLogin['user_type'] ?? 'employee').toString();

    if (userId.isEmpty) return;

    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;

      if (data == null) {
        await _databaseHelper.clearAllUserData();
        _showDeletedAccountAlert();
        return;
      }

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'suspended') {
        await _databaseHelper.clearAllUserData();
        _showSuspendedAlert();
        return;
      }

      await _fetchAndRegisterFcmToken();
      onAutoLogin(username, userId, userType);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _databaseHelper.clearAllUserData();
      }
    } catch (_) {}
  }

  // ─────────── GOOGLE SIGN-IN ───────────
  Future<bool> handleGoogleSignIn() async {
    try {
      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
        return false;
      }

      final response = await _apiClient.post(
        ApiEndpoints.googleAuth,
        data: {'token': idToken},
      );

      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : <String, dynamic>{};

      final String? accessToken = body['access_token']?.toString();
      final String? refreshToken = body['refresh_token']?.toString();

      if (accessToken == null || accessToken.isEmpty) {
        _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
        return false;
      }

      // FIX: Extract backend user_id first before falling back to googleUser.id
      final String resolvedUserId =
          (body['user_id'] ??
                  body['userId'] ??
                  body['id'] ??
                  body['user']?['id'] ??
                  body['user']?['user_id'] ??
                  googleUser.id)
              .toString()
              .trim();

      final String resolvedDisplayName =
          (body['username'] ??
                  body['name'] ??
                  googleUser.displayName ??
                  googleUser.email)
              .toString();

      _lastAuthenticatedUser = {
        'uid': resolvedUserId,
        'user_id': resolvedUserId,
        'display_name': resolvedDisplayName,
      };

      await _databaseHelper.saveCachedLoginWithTokens(
        resolvedDisplayName,
        accessToken,
        refreshToken ?? '',
        resolvedUserId,
        'employee',
      );

      await _fetchAndCacheAppConfig();
      await _fetchAndRegisterFcmToken();

      _showSuccessSnackBar(AppStrings.tr('login_success'));

      return true;
    } on GoogleSignInException catch (e) {
      if (e.code != 'sign_in_canceled' && e.code != 'canceled') {
        _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
      }
      return false;
    } on DioException {
      _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
      return false;
    } catch (e) {
      _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
      return false;
    }
  }

  /// Caches only the device-safe config values post-login (CDN name, Maps key);
  /// secrets are never cached. Best-effort — must not fail the login.
  Future<void> _fetchAndCacheAppConfig() async {
    try {
      final config = await _configRepo.getConfig();
      await _databaseHelper.saveConfig('cdn_cloud_name', config.cdnCloudName);
      await _databaseHelper.saveConfig(
        'google_maps_api_key',
        config.googleMapsApiKey,
      );
    } catch (_) {}
  }

  /// Registers this device's FCM token with the backend after login.
  /// Best-effort — must not fail the login.
  Future<void> _fetchAndRegisterFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();

      if (token == null || token.isEmpty) return;

      await _apiClient.patch(
        ApiEndpoints.updateFcmToken,
        data: {
          'fcm_tokens': [token],
        },
      );
    } catch (_) {}
  }

  // ─────────── SENSITIVE-ACTION RE-AUTHENTICATION ───────────

  /// Forces a fresh interactive Google sign-in to confirm [expectedEmail] before a
  /// sensitive action. Verifies Google identity only — doesn't touch the app session.
  Future<GoogleReauthResult> reauthenticateForSensitiveAction({
    required String expectedEmail,
  }) async {
    _showConnectingGoogleDialog();
    try {
      await _ensureGoogleSignInInitialized();

      // Drop any cached Google session so authenticate() always prompts the
      // account chooser instead of silently resolving to the last account.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final String signedInEmail = googleUser.email.trim().toLowerCase();
      final String expected = expectedEmail.trim().toLowerCase();

      if (expected.isNotEmpty && signedInEmail != expected) {
        return const GoogleReauthResult(GoogleReauthStatus.emailMismatch);
      }

      return GoogleReauthResult(
        GoogleReauthStatus.success,
        email: signedInEmail,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
        return const GoogleReauthResult(GoogleReauthStatus.cancelled);
      }
      return const GoogleReauthResult(GoogleReauthStatus.error);
    } catch (_) {
      return const GoogleReauthResult(GoogleReauthStatus.error);
    } finally {
      _dismissConnectingGoogleDialog();
    }
  }

  /// Shows a blocking "Connecting to Google..." indicator while sign-in is prepared.
  void _showConnectingGoogleDialog() {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SystemLoadingDialog(
        title: AppStrings.tr('connecting_google_title'),
        subtitle: AppStrings.tr('connecting_google_subtitle'),
      ),
    );
  }

  void _dismissConnectingGoogleDialog() {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> signOut() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {}
    await _googleSignIn.signOut();
    await _databaseHelper.clearCachedLogin();
  }

  // ─────────── LOGIN DATA / NAVIGATION ───────────

  Map<String, dynamic> getLoginData() {
    final user = _lastAuthenticatedUser;
    final String resolvedUserId = (user?['uid'] ?? '').toString().trim();

    return {
      'uid': resolvedUserId,
      'user_id': resolvedUserId,
      'userId': resolvedUserId,
      'username': (user?['display_name'] ?? '').toString(),
      'userType': 'employee',
    };
  }

  void navigateToMainApp(Map<String, dynamic> loginData) {
    Navigator.pushReplacementNamed(
      context,
      AppRoute.appmain,
      arguments: loginData,
    );
  }

  void showSuspendedAlert() {
    _showSuspendedAlert();
  }

  void showDeletedAccountAlert() {
    _showDeletedAccountAlert();
  }

  void _showSuspendedAlert() {
    /* Existing UI code */
  }
  void _showDeletedAccountAlert() {
    /* Existing UI code */
  }

  void _showErrorSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void autoLoginNavigation(String username, String userId, String userType) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.tr('logging_in_employee')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (context.mounted) {
        final String resolvedUserId = userId.trim();
        final loginData = {
          'uid': resolvedUserId,
          'user_id': resolvedUserId,
          'userId': resolvedUserId,
          'username': username,
          'userType': userType,
        };

        Navigator.pushReplacementNamed(
          context,
          AppRoute.appmain,
          arguments: loginData,
        );
      }
    });
  }
}
