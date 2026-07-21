// ignore_for_file: unrelated_type_equality_checks

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthLogic {
  final BuildContext context;
  final ApiClient _apiClient;
  final DatabaseHelper _databaseHelper;
  final GoogleSignIn _googleSignIn;

  Map<String, dynamic>? _lastAuthenticatedUser;
  bool _googleSignInInitialized = false;

  AuthLogic({
    required this.context,
    ApiClient? apiClient,
    DatabaseHelper? databaseHelper,
    GoogleSignIn? googleSignIn,
  }) : _apiClient = apiClient ?? ApiClient(),
       _databaseHelper = databaseHelper ?? DatabaseHelper(),
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

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
        await _databaseHelper.clearCachedLogin();
        _showDeletedAccountAlert();
        return;
      }

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'suspended') {
        await _databaseHelper.clearCachedLogin();
        _showSuspendedAlert();
        return;
      }

      onAutoLogin(username, userId, userType);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _databaseHelper.clearCachedLogin();
      }
    } catch (_) {}
  }

  // ─────────── GOOGLE SIGN-IN ───────────

  // ─────────── GOOGLE SIGN-IN ───────────

  Future<bool> handleGoogleSignIn() async {
    try {
      debugPrint('--- STARTING GOOGLE SIGN IN FLOW ---');
      await _ensureGoogleSignInInitialized();

      debugPrint('Waiting for user to select Google account...');
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      debugPrint('Google account selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint('FAILED: Google ID Token is null or empty');
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
        debugPrint('FAILED: Access token from backend is null or empty');
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

      _showSuccessSnackBar(AppStrings.tr('logging_in_employee'));

      debugPrint(
        'Saving tokens to local database with User ID: $resolvedUserId',
      );
      await _databaseHelper.saveCachedLoginWithTokens(
        resolvedDisplayName,
        accessToken,
        refreshToken ?? '',
        resolvedUserId,
        'employee',
      );

      debugPrint('--- LOGIN FLOW COMPLETED SUCCESSFULLY ---');
      return true;
    } on GoogleSignInException catch (e) {
      debugPrint('GOOGLE SIGN IN EXCEPTION: [${e.code}] ${e.toString()}');
      if (e.code != 'sign_in_canceled' && e.code != 'canceled') {
        _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
      }
      return false;
    } on DioException catch (e) {
      debugPrint('DIO API EXCEPTION: ${e.message}');
      _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
      return false;
    } catch (e) {
      debugPrint('UNKNOWN EXCEPTION CAUGHT: $e');
      _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
      return false;
    }
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
        backgroundColor: Colors.red,
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
