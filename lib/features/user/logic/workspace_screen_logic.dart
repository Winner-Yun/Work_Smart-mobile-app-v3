import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/workspace_screen.dart';
import 'package:flutter_worksmart_app/features/user/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/workspace_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/service/workspace_service.dart';
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

  static const String _cacheKeyWorkspaces = 'cached_workspaces';
  static const String _cacheKeyUser = 'cached_workspace_user';
  static const String _cacheKeyTimestamp = 'cached_workspace_data_timestamp';

  static const Duration _cacheMaxAge = Duration(minutes: 10);

  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _workspaceRepo = WorkspaceRepository(WorkspaceService());
    _userRepo = UserRepository(UserService());
    _initData();
  }

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

  // Local-first: load cached data instantly, then decide if a network fetch is needed.
  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await _loadFromLocal();

    if (!mounted) return;

    final bool hasAnyLocalData = hasLocalUser || hasLocalWorkspaces;

    if (hasAnyLocalData) {
      // Keep loader up briefly so it doesn't read as a jarring instant pop-in.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = null;
      });
      if (_isCacheExpired()) {
        _fetchFromNetwork(showLoading: false);
      }
    } else {
      await _fetchFromNetwork(showLoading: true);
    }
  }

  Future<void> _loadFromLocal() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final cachedWorkspacesJson = prefs.getString(_cacheKeyWorkspaces);
    if (cachedWorkspacesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedWorkspacesJson);
        workspaces = decoded
            .map((json) => Workspace.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final cachedUserJson = prefs.getString(_cacheKeyUser);
    if (cachedUserJson != null) {
      try {
        currentUser = UserModel.fromJson(jsonDecode(cachedUserJson));
      } catch (_) {}
    }

    if (currentUser == null) {
      try {
        final dbProfile = await DatabaseHelper().getUserProfile();
        if (dbProfile != null) {
          currentUser = UserModel.fromJson(dbProfile);
          await prefs.setString(
            _cacheKeyUser,
            jsonEncode(currentUser!.toJson()),
          );
        }
      } catch (_) {}
    }

    if (currentUser == null) {
      final localFromLogin = _tryParseUserFromLoginData();
      if (localFromLogin != null) {
        currentUser = localFromLogin;
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

  UserModel? _tryParseUserFromLoginData() {
    final data = widget.loginData;
    if (data == null || data.isEmpty) return null;
    try {
      final Map<String, dynamic> candidate;
      if (data.containsKey('user') && data['user'] is Map) {
        candidate = Map<String, dynamic>.from(data['user'] as Map);
      } else {
        candidate = Map<String, dynamic>.from(data);
      }
      if (candidate['name'] == null &&
          candidate['email'] == null &&
          candidate['_id'] == null &&
          candidate['id'] == null) {
        return null;
      }
      return UserModel.fromJson(candidate);
    } catch (e) {
      return null;
    }
  }

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
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
          if (workspaces.isEmpty && currentUser == null) {
            errorMessage = AppStrings.tr('load_data_failed_retry');
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
        } catch (_) {}
      }

      await prefs.setInt(
        _cacheKeyTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
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
