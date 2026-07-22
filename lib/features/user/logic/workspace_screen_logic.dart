import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/workspace_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/workspace_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/workspace_screen.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class WorkspaceScreenLogic extends State<WorkspaceScreen> {
  late final WorkspaceRepository _workspaceRepo;
  late final UserRepository _userRepo;

  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;

  List<Workspace> workspaces = [];
  UserModel? currentUser;
  String? selectedWorkspaceId;

  // --- Caching constants ---
  static const String _cacheKeyWorkspaces = 'cached_workspaces';
  static const String _cacheKeyUser = 'cached_workspace_user';
  static const String _cacheKeyTimestamp = 'cached_workspace_data_timestamp';

  /// Cache is considered stale after this duration.
  static const Duration _cacheMaxAge = Duration(minutes: 10);

  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _workspaceRepo = WorkspaceRepository(WorkspaceService());
    _userRepo = UserRepository(UserService());
    _initData();
  }

  /// Public getter so the UI can check whether a force-refresh is needed.
  bool get shouldForceRefresh => _isCacheExpired();

  bool get hasLocalUser => currentUser != null;
  bool get hasLocalWorkspaces => workspaces.isNotEmpty;

  bool _isCacheExpired() {
    final prefs = _prefs;
    if (prefs == null) return true;
    final cachedTimestamp = prefs.getInt(_cacheKeyTimestamp);
    if (cachedTimestamp == null) return true;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
    return DateTime.now().difference(cachedAt) > _cacheMaxAge;
  }

  /// Local-first init: load from SharedPreferences + SQLite + loginData instantly,
  /// then decide if network fetch is needed.
  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 1. Load everything we have locally first (instant UI)
    await _loadFromLocal();

    if (!mounted) return;

    final bool hasAnyLocalData = hasLocalUser || hasLocalWorkspaces;

    if (hasAnyLocalData) {
      // Show local data immediately, no full-screen loader
      setState(() {
        isLoading = false;
        errorMessage = null;
      });
      // Background refresh if stale
      if (_isCacheExpired()) {
        _fetchFromNetwork(showLoading: false);
      }
    } else {
      // No local data at all -> need network with loader
      await _fetchFromNetwork(showLoading: true);
    }
  }

  /// Loads user profile from multiple local sources in priority order:
  /// 1. SharedPreferences cached user
  /// 2. SQLite user_profile_cache
  /// 3. widget.loginData (passed from auth)
  /// And workspaces from SharedPreferences.
  Future<void> _loadFromLocal() async {
    final prefs = _prefs;
    if (prefs == null) return;

    // --- Workspaces from SharedPreferences ---
    final cachedWorkspacesJson = prefs.getString(_cacheKeyWorkspaces);
    if (cachedWorkspacesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedWorkspacesJson);
        workspaces = decoded
            .map((json) => Workspace.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint(
          '✅ [WorkspaceScreenLogic] Loaded ${workspaces.length} workspaces from local cache',
        );
      } catch (e) {
        debugPrint(
          '⛔ [WorkspaceScreenLogic] Error parsing cached workspaces: $e',
        );
      }
    }

    // --- User from SharedPreferences ---
    final cachedUserJson = prefs.getString(_cacheKeyUser);
    if (cachedUserJson != null) {
      try {
        currentUser = UserModel.fromJson(jsonDecode(cachedUserJson));
        debugPrint(
          '✅ [WorkspaceScreenLogic] Loaded user from SharedPreferences: ${currentUser?.name}',
        );
      } catch (e) {
        debugPrint('⛔ [WorkspaceScreenLogic] Error parsing cached user: $e');
      }
    }

    // --- User from SQLite (fallback) ---
    if (currentUser == null) {
      try {
        final dbProfile = await DatabaseHelper().getUserProfile();
        if (dbProfile != null) {
          currentUser = UserModel.fromJson(dbProfile);
          debugPrint(
            '✅ [WorkspaceScreenLogic] Loaded user from SQLite: ${currentUser?.name}',
          );
          // Sync back to SharedPreferences for faster next load
          await prefs.setString(
            _cacheKeyUser,
            jsonEncode(currentUser!.toJson()),
          );
        }
      } catch (e) {
        debugPrint(
          '⛔ [WorkspaceScreenLogic] Error loading user profile from DB: $e',
        );
      }
    }

    // --- User from loginData (last fallback, also local) ---
    if (currentUser == null) {
      final localFromLogin = _tryParseUserFromLoginData();
      if (localFromLogin != null) {
        currentUser = localFromLogin;
        debugPrint(
          '✅ [WorkspaceScreenLogic] Loaded user from loginData: ${currentUser?.name}',
        );
        // Persist this to both caches so next launch is instant
        try {
          await prefs.setString(
            _cacheKeyUser,
            jsonEncode(currentUser!.toJson()),
          );
          await DatabaseHelper().saveUserProfile(currentUser!.toJson());
        } catch (_) {}
      }
    }
  }

  /// Tries to build a UserModel from widget.loginData if available.
  UserModel? _tryParseUserFromLoginData() {
    final data = widget.loginData;
    if (data == null || data.isEmpty) return null;
    try {
      // loginData may already be a UserModel-like map or contain nested user
      final Map<String, dynamic> candidate;
      if (data.containsKey('user') && data['user'] is Map) {
        candidate = Map<String, dynamic>.from(data['user'] as Map);
      } else {
        candidate = Map<String, dynamic>.from(data);
      }
      // Only build if we have at least a name or email or id
      if (candidate['name'] == null &&
          candidate['email'] == null &&
          candidate['_id'] == null &&
          candidate['id'] == null) {
        return null;
      }
      return UserModel.fromJson(candidate);
    } catch (e) {
      debugPrint(
        '⛔ [WorkspaceScreenLogic] Error parsing user from loginData: $e',
      );
      return null;
    }
  }

  /// Fetches workspaces and user profile from the network,
  /// then caches the results locally.
  Future<void> _fetchFromNetwork({required bool showLoading}) async {
    if (showLoading) {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isRefreshing = true;
        });
      }
    }

    try {
      final results = await Future.wait([
        _workspaceRepo.getWorkspaces(),
        _userRepo.getUserProfile(),
      ]);

      if (!mounted) return;

      setState(() {
        workspaces = results[0] as List<Workspace>;
        currentUser = results[1] as UserModel;
        isLoading = false;
        isRefreshing = false;
        errorMessage = null;
      });

      await _saveToCache();
    } catch (e) {
      debugPrint('⛔ [WorkspaceScreenLogic] Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
          if (workspaces.isEmpty && currentUser == null) {
            errorMessage = 'Failed to load data. Please try again.';
          }
        });
      }
    }
  }

  Future<void> _saveToCache() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final workspacesJson = jsonEncode(
        workspaces.map((w) => w.toJson()).toList(),
      );
      await prefs.setString(_cacheKeyWorkspaces, workspacesJson);

      if (currentUser != null) {
        final userJson = currentUser!.toJson();
        await prefs.setString(_cacheKeyUser, jsonEncode(userJson));
        try {
          await DatabaseHelper().saveUserProfile(userJson);
        } catch (e) {
          debugPrint(
            '⛔ [WorkspaceScreenLogic] Error saving user profile to DB: $e',
          );
        }
      }

      await prefs.setInt(
        _cacheKeyTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('⛔ [WorkspaceScreenLogic] Error saving cache: $e');
    }
  }

  void onWorkspaceSelected(String id) {
    setState(() {
      selectedWorkspaceId = id;
    });
  }

  void onConfirmSelection() {
    if (selectedWorkspaceId == null) return;
    widget.onWorkspaceConfirmed(selectedWorkspaceId!);
  }

  Future<void> onRetry() async {
    await _fetchFromNetwork(showLoading: true);
  }

  Future<void> onRefresh() async {
    await _fetchFromNetwork(showLoading: false);
  }

  @override
  void dispose() {
    _prefs = null;
    super.dispose();
  }
}
