import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/map_styles.dart';
import 'package:flutter_worksmart_app/core/util/database/attendance_data.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/database/office_data.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/core/util/notification/local_notification_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/geofence_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/policy_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/workspace_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/geofence_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/policy_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/workspace_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/homepagescreen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/workspace_screen.dart';
import 'package:flutter_worksmart_app/shared/model/geofence_model.dart';
import 'package:flutter_worksmart_app/shared/model/policy_model.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum _PermissionResolutionAction { retry, settings, notNow }

abstract class HomePageLogic extends State<HomePageScreen> {
  static String get _userLocationMarkerTitle => AppStrings.tr('map_marker_me');

  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();

  // --- Repositories & Services ---
  late final GeofenceRepository _geofenceRepo;
  late final PolicyRepository _policyRepo;
  late final WorkspaceRepository _workspaceRepo;

  Workspace? currentWorkspace;
  GeofenceModel? currentGeofence;
  PolicyModel? currentPolicy;
  bool isRefreshing = false;

  String get workspaceName => currentWorkspace?.workspaceName.isNotEmpty == true
      ? currentWorkspace!.workspaceName
      : officeName;
  String get workspaceDescription =>
      currentWorkspace?.description.isNotEmpty == true
      ? currentWorkspace!.description
      : 'Active Workspace Zone';
  int get workspaceMemberCount => currentWorkspace?.memberCount ?? 1;
  // --- Data Models ---
  late UserModel currentUser;
  late List<UserModel> allEmployees;
  late String? loggedInUserId;

  final List<Map<String, dynamic>> _userRecordsData = usersFinalData
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final Map<String, dynamic> _officeConfigData = Map<String, dynamic>.from(
    officeMasterData,
  );
  final Map<String, dynamic> _currentFaceBiometricsData = <String, dynamic>{};

  // --- State Variables ---
  GoogleMapController? mapController;
  StreamSubscription<Position>? positionStreamSubscription;

  late String currentFaceStatus;

  // --- Office Configuration  ---
  late LatLng officeLocation;
  late double scanRangeMeters;
  late String officeName;
  late String officeCheckInTime;
  late String officeCheckOutTime;
  late int lateBufferMinutes;
  late int deadlineScanMinutes;

  // --- UI State Tracking ---
  bool isInitialDataLoading = true;
  bool isInRange = false;
  bool isDeveloperModeDetected = false;
  String rangeStatusText = AppStrings.tr('finding_location');
  Position? lastKnownPosition;
  bool hasMockScanSuccess = false;
  DateTime? lastMockScanAt;
  String selectedAttendanceScanType = 'check_in';
  String lastMockScanType = 'check_in';
  String? overrideCheckInTime;
  String? overrideCheckOutTime;
  double? overrideTotalHours;
  final Map<String, bool> attendanceScanStatus = {
    'check_in': false,
    'check_out': false,
  };
  final Map<String, DateTime?> attendanceScanSuccessAt = {
    'check_in': null,
    'check_out': null,
  };
  late int checkOutScanAllowMinutes;
  int checkOutCooldownSeconds = 0;
  Timer? _checkOutCooldownTimer;
  Timer? _deadlineRefreshTimer;

  // --- Map Objects ---
  Set<Marker> markers = {};
  final Set<Circle> circles = {};
  BitmapDescriptor? userProfileIcon;
  bool _startupFlowStarted = false;
  bool _developerModeWarningShown = false;

  Stream<List<Map<String, dynamic>>> watchUserNotificationItems() {
    final String uid = (loggedInUserId ?? '').toString().trim();
    if (uid.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }
    return _realtimeDataController.watchUserNotifications(uid);
  }

  bool shouldShowNotificationDot(List<Map<String, dynamic>> notifications) {
    return notifications.any((item) {
      final raw = item['isRead'] ?? item['is_read'];
      if (raw is bool) return raw == false;
      final normalized = (raw ?? '').toString().trim().toLowerCase();
      return normalized == 'false' || normalized == '0' || normalized == 'no';
    });
  }

  @override
  void initState() {
    super.initState();
    _geofenceRepo = GeofenceRepository(GeofenceService());
    _policyRepo = PolicyRepository(PolicyService());
    _workspaceRepo = WorkspaceRepository(WorkspaceService());
    loggedInUserId = widget.loginData?['uid'];
    _loadAllData();
    setupOfficeMapObjects();
    generateProfileMarker();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupPermissionFlow();
    });
  }

  Future<void> _runStartupPermissionFlow() async {
    if (_startupFlowStarted || !mounted) {
      return;
    }

    _startupFlowStarted = true;
    await LocalNotificationService.instance.initialize();

    final bool locationGranted = await _handleLocationPermissionStep();
    await _handleNotificationPermissionStep();
    await _handleCameraPermissionStep();

    if (mounted) {
      widget.onStartupFlowCompleted?.call();
    }

    if (!locationGranted && mounted) {
      setState(() => rangeStatusText = AppStrings.tr('perm_needed'));
    }
  }

  Future<bool> _handleLocationPermissionStep() async {
    if (kIsWeb) {
      return true;
    }

    bool hasRequestedOnce = false;
    while (mounted) {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await initLocationTracking(skipPermissionRequest: true);
        return true;
      }

      if (!hasRequestedOnce && permission == LocationPermission.denied) {
        hasRequestedOnce = true;
        final LocationPermission requested =
            await Geolocator.requestPermission();
        if (requested == LocationPermission.always ||
            requested == LocationPermission.whileInUse) {
          await initLocationTracking(skipPermissionRequest: true);
          return true;
        }
      }

      final _PermissionResolutionAction
      action = await _showPermissionResolutionDialog(
        title: 'Location Permission Required',
        message:
            'Location access is needed to verify attendance range and update your office map status.',
        canRetry: permission != LocationPermission.deniedForever,
      );

      if (action == _PermissionResolutionAction.retry) {
        hasRequestedOnce = false;
        continue;
      }

      if (action == _PermissionResolutionAction.settings) {
        await openAppSettings();
        continue;
      }

      return false;
    }

    return false;
  }

  Future<void> _detectDeveloperModeOnHomepage() async {
    if (kIsWeb || _developerModeWarningShown || !mounted) {
      return;
    }

    bool fakeLocationDetected = false;
    bool developerModeDetected = false;

    try {
      fakeLocationDetected = await DetectFakeLocation().detectFakeLocation();
    } catch (_) {
      fakeLocationDetected = false;
    }

    try {
      developerModeDetected = await FlutterJailbreakDetection.developerMode;
    } catch (_) {
      developerModeDetected = false;
    }

    if (!fakeLocationDetected && !developerModeDetected) {
      return;
    }

    _developerModeWarningShown = true;
    if (!mounted) {
      return;
    }

    setState(() {
      isDeveloperModeDetected = true;
      isInRange = false;
      rangeStatusText = AppStrings.tr('mock_gps_label');
    });

    await _showDeveloperModeWarningAndExit(
      message: fakeLocationDetected
          ? AppStrings.tr('mock_gps_warning')
          : AppStrings.tr('developer_mode_alert_message'),
    );
  }

  Future<void> _showDeveloperModeWarningAndExit({
    required String message,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.tr('developer_mode_alert_title')),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => SystemNavigator.pop(),
              child: Text(AppStrings.tr('exit_app')),
            ),
          ],
        );
      },
    );

    if (mounted) {
      SystemNavigator.pop();
    }
  }

  Future<void> _handleNotificationPermissionStep() async {
    if (kIsWeb) {
      return;
    }

    await _requestPermissionWithResolution(
      permission: Permission.notification,
      title: 'Notification Permission Required',
      message:
          'Notifications keep you informed about attendance and leave status updates in real time.',
    );
  }

  Future<void> _handleCameraPermissionStep() async {
    if (kIsWeb) {
      return;
    }

    await _requestPermissionWithResolution(
      permission: Permission.camera,
      title: 'Camera Permission Required',
      message:
          'Camera access is needed for face scan attendance verification from the homepage.',
    );
  }

  Future<bool> _requestPermissionWithResolution({
    required Permission permission,
    required String title,
    required String message,
  }) async {
    bool hasRequestedOnce = false;

    while (mounted) {
      final PermissionStatus status = await permission.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final bool canRetry =
          !status.isPermanentlyDenied &&
          !status.isRestricted &&
          !status.isLimited;

      if (!hasRequestedOnce && canRetry) {
        hasRequestedOnce = true;
        final PermissionStatus requestedStatus = await permission.request();
        if (requestedStatus.isGranted || requestedStatus.isLimited) {
          return true;
        }
      }

      final _PermissionResolutionAction action =
          await _showPermissionResolutionDialog(
            title: title,
            message: message,
            canRetry: canRetry,
          );

      if (action == _PermissionResolutionAction.retry) {
        hasRequestedOnce = false;
        continue;
      }

      if (action == _PermissionResolutionAction.settings) {
        await openAppSettings();
        continue;
      }

      return false;
    }

    return false;
  }

  Future<_PermissionResolutionAction> _showPermissionResolutionDialog({
    required String title,
    required String message,
    required bool canRetry,
  }) async {
    if (!mounted) {
      return _PermissionResolutionAction.notNow;
    }

    final _PermissionResolutionAction? action =
        await showDialog<_PermissionResolutionAction>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                if (canRetry)
                  TextButton(
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop(_PermissionResolutionAction.retry),
                    child: const Text('Retry'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_PermissionResolutionAction.settings),
                  child: const Text('Open Settings'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_PermissionResolutionAction.notNow),
                  child: const Text('Not Now'),
                ),
              ],
            );
          },
        );

    return action ?? _PermissionResolutionAction.notNow;
  }

  Future<Map<String, dynamic>?> _loadCachedUserProfile() async {
    try {
      return await DatabaseHelper().getUserProfile();
    } catch (e) {
      debugPrint('[_loadCachedUserProfile] Error loading from DB: $e');
      return null;
    }
  }

  Future<void> _fetchAndSaveUserProfile() async {
    try {
      final userRepository = UserRepository(UserService());
      final UserModel userModel = await userRepository.getUserProfile();
      final Map<String, dynamic> userJson = userModel.toJson();
      await DatabaseHelper().saveUserProfile(userJson);
      debugPrint('[_fetchAndSaveUserProfile] Saved user profile to local DB');
    } catch (e) {
      debugPrint('[_fetchAndSaveUserProfile] Error: $e');
    }
  }

  Future<void> _loadData() async {
    final userDataSource = _userRecordsData.isNotEmpty
        ? _userRecordsData
        : usersFinalData;

    final safeUserDataSource = userDataSource.isNotEmpty
        ? userDataSource
        : <Map<String, dynamic>>[defaultUserRecord];

    final currentUserData = safeUserDataSource.firstWhere(
      (user) => user['uid'] == loggedInUserId,
      orElse: () => safeUserDataSource.first,
    );

    final String staticUserName =
        (currentUserData['display_name'] ?? currentUserData['name'])
            ?.toString() ??
        '';
    Map<String, dynamic>? effectiveUserData = currentUserData;
    if (staticUserName.trim().isEmpty) {
      final cachedProfile = await _loadCachedUserProfile();
      if (cachedProfile != null) {
        effectiveUserData = cachedProfile;
      }
    }

    currentUser = UserModel.fromJson(effectiveUserData);
    final Map<String, dynamic> faceData = _currentFaceBiometricsData;
    final normalizedFaceStatus = (faceData['face_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final int faceCount =
        int.tryParse((faceData['face_count'] ?? 0).toString()) ?? 0;
    final bool hasFaceVector =
        (faceData['face_embedding_vector'] is List) ||
        (faceData['face_embeddings'] is List) ||
        (faceData['face_vectors'] is List);
    final bool hasFaceSamples = faceCount > 0 || hasFaceVector;
    currentFaceStatus = normalizedFaceStatus.isEmpty
        ? 'uninitialized'
        : (normalizedFaceStatus == 'pending' && hasFaceSamples
              ? 'approved'
              : normalizedFaceStatus);

    allEmployees = safeUserDataSource
        .map((json) => UserModel.fromJson(json))
        .toList();

    officeLocation = _resolveOfficeLocation();

    final geofence =
        (_officeConfigData['geofence'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    scanRangeMeters = _toDouble(
      geofence['radius_meters'] ??
          geofence['radiusMeters'] ??
          geofence['radius'],
      fallback: 50,
    );
    if (currentWorkspace != null &&
        currentWorkspace!.workspaceName.isNotEmpty) {
      officeName = currentWorkspace!.workspaceName;
    } else if (currentGeofence != null && currentGeofence!.name.isNotEmpty) {
      officeName = currentGeofence!.name;
    } else {
      officeName =
          _officeConfigData['office_name']?.toString() ?? 'Main Office';
    }

    final Map<String, dynamic> policy = _asStringKeyMap(
      _officeConfigData['policy'],
    );
    officeCheckInTime = _readStringByKeys(policy, const [
      'check_in_start',
      'checkInStart',
    ], fallback: '09:00 AM');
    officeCheckOutTime = _readStringByKeys(policy, const [
      'check_out_end',
      'checkOutEnd',
    ], fallback: '06:00 PM');

    final dynamic rawAllowMinutes =
        _readByKeys(policy, const [
          'check_out_scan_allow_minutes',
          'checkOutScanAllowMinutes',
        ]) ??
        _readByKeys(_officeConfigData, const [
          'check_out_scan_allow_minutes',
          'checkOutScanAllowMinutes',
        ]);
    checkOutScanAllowMinutes = _parsePositiveInt(rawAllowMinutes, fallback: 30);

    final dynamic rawLateBufferMinutes =
        _readByKeys(policy, const [
          'late_buffer_minutes',
          'lateBufferMinutes',
        ]) ??
        _readByKeys(_officeConfigData, const [
          'late_buffer_minutes',
          'lateBufferMinutes',
        ]);
    lateBufferMinutes = _parsePositiveInt(rawLateBufferMinutes, fallback: 15);

    final dynamic rawDeadlineScanMinutes =
        _readByKeys(policy, const [
          'deadline_scan_minutes',
          'deadlineScanMinutes',
        ]) ??
        _readByKeys(_officeConfigData, const [
          'deadline_scan_minutes',
          'deadlineScanMinutes',
        ]);
    deadlineScanMinutes = _parseNonNegativeInt(rawDeadlineScanMinutes);

    _syncScanStateFromAttendanceData();
  }

  Future<void> _loadLocalWorkspaceAndConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString('selected_workspace_id');

      final cachedWorkspaceJson = prefs.getString('cached_selected_workspace');
      bool hasMatchingCache = false;

      // 1. Check if the cached active workspace matches the newly selected ID
      if (cachedWorkspaceJson != null) {
        final cachedWs = Workspace.fromJson(jsonDecode(cachedWorkspaceJson));
        if (selectedId == null || cachedWs.id == selectedId) {
          currentWorkspace = cachedWs;
          hasMatchingCache = true;
        }
      }

      // 2. If it doesn't match (user switched), pull the new name instantly from the workspaces list
      if (!hasMatchingCache && selectedId != null) {
        final cachedWorkspacesJson = prefs.getString('cached_workspaces');
        if (cachedWorkspacesJson != null) {
          final List<dynamic> decoded = jsonDecode(cachedWorkspacesJson);
          for (final item in decoded) {
            if (item is Map<String, dynamic> &&
                item['id']?.toString() == selectedId) {
              currentWorkspace = Workspace.fromJson(item);
              // Update the active cache instantly so it doesn't lag
              await prefs.setString(
                'cached_selected_workspace',
                jsonEncode(item),
              );
              break;
            }
          }
        }
      }

      final cachedGeofenceJson = prefs.getString('cached_homepage_geofence');
      if (cachedGeofenceJson != null) {
        final Map<String, dynamic> geofenceMap = jsonDecode(cachedGeofenceJson);
        currentGeofence = GeofenceModel.fromJson(geofenceMap);
        _officeConfigData['geofence'] = geofenceMap;
      }

      final cachedPolicyJson = prefs.getString('cached_homepage_policy');
      if (cachedPolicyJson != null) {
        final Map<String, dynamic> policyMap = jsonDecode(cachedPolicyJson);
        currentPolicy = PolicyModel.fromJson(policyMap);
        _officeConfigData['policy'] = policyMap;
      }
    } catch (e) {
      debugPrint('[_loadLocalWorkspaceAndConfig] Error: $e');
    }
  }

  Future<void> _fetchWorkspaceGeofenceAndPolicy({
    bool showRefreshing = false,
  }) async {
    if (showRefreshing && mounted) {
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedWorkspaceId = prefs.getString('selected_workspace_id');

      if (selectedWorkspaceId != null && selectedWorkspaceId.isNotEmpty) {
        final results = await Future.wait([
          _workspaceRepo.getWorkspaces().catchError((_) => <Workspace>[]),
          _geofenceRepo
              .getGeofence(selectedWorkspaceId)
              .then((g) => g as dynamic)
              .catchError((_) => null),
          _policyRepo
              .getPolicy(selectedWorkspaceId)
              .then((p) => p as dynamic)
              .catchError((_) => null),
        ]);

        final List<Workspace> fetchedWorkspaces = results[0] as List<Workspace>;
        final GeofenceModel? fetchedGeofence = results[1] as GeofenceModel?;
        final PolicyModel? fetchedPolicy = results[2] as PolicyModel?;

        if (fetchedWorkspaces.isNotEmpty) {
          final matching = fetchedWorkspaces.firstWhere(
            (w) => w.id == selectedWorkspaceId,
            orElse: () => fetchedWorkspaces.first,
          );
          currentWorkspace = matching;
          await prefs.setString(
            'cached_selected_workspace',
            jsonEncode(matching.toJson()),
          );
          final workspacesJson = jsonEncode(
            fetchedWorkspaces.map((w) => w.toJson()).toList(),
          );
          await prefs.setString('cached_workspaces', workspacesJson);
        }

        if (fetchedGeofence != null) {
          currentGeofence = fetchedGeofence;
          final geofenceMap = {
            'id': fetchedGeofence.id,
            'workspace_id': fetchedGeofence.workspaceId,
            'name': fetchedGeofence.name,
            'latitude': fetchedGeofence.latitude,
            'longitude': fetchedGeofence.longitude,
            'radius_meters': fetchedGeofence.radiusMeters,
            'status': fetchedGeofence.status,
            'center': {
              'lat': fetchedGeofence.latitude,
              'lng': fetchedGeofence.longitude,
            },
          };
          _officeConfigData['geofence'] = geofenceMap;
          await prefs.setString(
            'cached_homepage_geofence',
            jsonEncode(geofenceMap),
          );
        }

        if (fetchedPolicy != null) {
          currentPolicy = fetchedPolicy;
          final policyMap = {
            'id': fetchedPolicy.id,
            'workspace_id': fetchedPolicy.workspaceId,
            'name': fetchedPolicy.name,
            'work_start_time': fetchedPolicy.workStartTime,
            'work_end_time': fetchedPolicy.workEndTime,
            'check_in_start': fetchedPolicy.checkInStart,
            'check_out_start': fetchedPolicy.checkOutStart,
            'late_buffer_minutes': fetchedPolicy.lateBufferMinutes,
            'deadline_scan_minutes': fetchedPolicy.deadlineScanMinutes,
            'annual_leave_limit': fetchedPolicy.annualLeaveLimit,
            'sick_leave_limit': fetchedPolicy.sickLeaveLimit,
            'status': fetchedPolicy.status,
          };
          _officeConfigData['policy'] = policyMap;
          await prefs.setString(
            'cached_homepage_policy',
            jsonEncode(policyMap),
          );
        }
      }
    } catch (e) {
      debugPrint('[_fetchWorkspaceGeofenceAndPolicy] Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> onRefresh() async {
    // Show skeleton loader on manual refresh / workspace reload
    if (mounted) {
      setState(() {
        isRefreshing = true;
      });
    }

    await _fetchAndSaveUserProfile();
    await _fetchWorkspaceGeofenceAndPolicy(showRefreshing: true);
    await _loadData();
    await setupOfficeMapObjects();

    if (mounted) {
      setState(() {
        isRefreshing = false;
      });
    }
  }

  Future<void> _loadAllData() async {
    await _fetchAndSaveUserProfile();

    await _loadLocalWorkspaceAndConfig();
    await _loadData();

    if (mounted) {
      setState(() {
        isInitialDataLoading = false;
      });
    }

    _fetchWorkspaceGeofenceAndPolicy().then((_) async {
      if (mounted) {
        await _loadData();
        await setupOfficeMapObjects();
      }
    });
  }

  void _syncScanStateFromAttendanceData() {
    final bool checkInDone = _isTypeCompleted('check_in');
    final bool checkOutDone = _isTypeCompleted('check_out');

    if (checkOutDone) {
      _stopCheckOutCooldown();
      selectedAttendanceScanType = 'check_out';
      hasMockScanSuccess = true;
      lastMockScanType = 'check_out';
      final String checkOutTime = (currentAttendance['check_out'] ?? '--:--')
          .toString();
      lastMockScanAt = _parse12hTime(checkOutTime);
      _syncDeadlineRefreshWatcher();
      return;
    }

    if (checkInDone) {
      selectedAttendanceScanType = 'check_out';
      hasMockScanSuccess = false;
      lastMockScanType = 'check_in';
      lastMockScanAt = null;
      final DateTime? checkInAt = _getCompletedTypeTime('check_in');
      _syncCheckOutCooldownFromCheckIn(checkInAt);
      _syncDeadlineRefreshWatcher();
      return;
    }

    _stopCheckOutCooldown();
    selectedAttendanceScanType = 'check_in';
    hasMockScanSuccess = false;
    lastMockScanAt = null;
    _syncDeadlineRefreshWatcher();
  }

  // --- Getters for UI Consumption ---
  String _getDisplayFirstName(String? fullName) {
    if (fullName == null) return '';
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.first;
  }

  String get currentUserDisplayName => currentUser.name;

  List<Map<String, dynamic>> get employeeListDisplayData {
    final sortedEmployees = List<UserProfile>.from(allEmployees)
      ..sort((a, b) {
        final scoreA = a.achievements.performanceScore;
        final scoreB = b.achievements.performanceScore;
        return scoreB.compareTo(scoreA);
      });

    return List.generate(sortedEmployees.length, (index) {
      final user = sortedEmployees[index];
      final rank = index + 1;

      return {
        "name": _getDisplayFirstName(user.displayName),
        "role": user.roleTitle,
        "score":
            "${user.achievements.performanceScore} ${AppStrings.tr('points_label')}",
        "imgUrl": user.profileUrl,
        "isTop": rank < 2,
      };
    });
  }

  List<Map<String, dynamic>> get leaveStatisticsData {
    final policy =
        (_officeConfigData['policy'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final int annualLimit =
        (policy['annual_leave_limit'] as num?)?.toInt() ?? 0;
    final int sickLimit = (policy['sick_leave_limit'] as num?)?.toInt() ?? 0;

    int calculateTaken(String type) {
      return 0; // Integration point
    }

    final int annualTaken = calculateTaken('annual_leave');
    final int sickTaken = calculateTaken('sick_leave');

    final annualProgress = annualLimit > 0
        ? (annualTaken / annualLimit).clamp(0.0, 1.0)
        : 0.0;
    final sickProgress = sickLimit > 0
        ? (sickTaken / sickLimit).clamp(0.0, 1.0)
        : 0.0;

    return [
      {
        "icon": Icons.beach_access,
        "label": "annual_leave",
        "amount": "$annualLimit",
        "color": Colors.blue,
        "progress": annualProgress,
        "used": annualTaken,
        "remaining": (annualLimit - annualTaken).clamp(0, annualLimit),
      },
      {
        "icon": Icons.sick_outlined,
        "label": "sick_leave",
        "amount": "$sickLimit",
        "color": Colors.purple,
        "progress": sickProgress,
        "used": sickTaken,
        "remaining": (sickLimit - sickTaken).clamp(0, sickLimit),
      },
    ];
  }

  Map<String, dynamic> get currentAttendance {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      final todayRecord = attendanceRecords.firstWhere(
        (record) =>
            record['uid'] == currentUser.id && record['date'] == todayStr,
      );

      final Map<String, dynamic> attendance = {
        'date': todayStr,
        'check_in': todayRecord['check_in'] ?? '--:--',
        'check_out': todayRecord['check_out'] ?? '--:--',
        'total_hours': todayRecord['total_hours'] ?? 0.0,
        'status': todayRecord['status'] ?? 'absent',
      };
      if (overrideCheckInTime != null) {
        attendance['check_in'] = overrideCheckInTime;
      }
      if (overrideCheckOutTime != null) {
        attendance['check_out'] = overrideCheckOutTime;
      }
      if (overrideTotalHours != null) {
        attendance['total_hours'] = overrideTotalHours;
      }
      return attendance;
    } catch (e) {
      final Map<String, dynamic> attendance = {
        'date': todayStr,
        'check_in': '--:--',
        'check_out': '--:--',
        'total_hours': 0.0,
        'status': 'not_checked_in',
      };
      if (overrideCheckInTime != null) {
        attendance['check_in'] = overrideCheckInTime;
      }
      if (overrideCheckOutTime != null) {
        attendance['check_out'] = overrideCheckOutTime;
      }
      if (overrideTotalHours != null) {
        attendance['total_hours'] = overrideTotalHours;
      }
      return attendance;
    }
  }

  void selectAttendanceScanType(String type) {
    if (type != 'check_in' && type != 'check_out') return;

    if (type == 'check_out' && !_isTypeCompleted('check_in')) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          title: Text(
            AppStrings.tr('check_out_requires_check_in'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppStrings.tr('check_out_requires_check_in_desc'),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppStrings.tr('understood')),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        selectedAttendanceScanType = type;
        final bool alreadyScanned = _isTypeCompleted(type);
        if (alreadyScanned) {
          hasMockScanSuccess = true;
          lastMockScanType = type;
          lastMockScanAt = _getCompletedTypeTime(type);

          if (type == 'check_out') {
            _stopCheckOutCooldown();
          }
        } else {
          hasMockScanSuccess = false;
          lastMockScanAt = null;

          if (type == 'check_out') {
            final DateTime? checkInAt = _getCompletedTypeTime('check_in');
            _syncCheckOutCooldownFromCheckIn(checkInAt);
          }
        }
      });
    }
  }

  bool get isSelectedScanCompleted =>
      _isTypeCompleted(selectedAttendanceScanType);

  bool get isScanCooldownActive =>
      selectedAttendanceScanType == 'check_out' && checkOutCooldownSeconds > 0;

  bool get isCheckOutScanDeadlineReached {
    if (selectedAttendanceScanType != 'check_out') {
      return false;
    }
    if (!_isTypeCompleted('check_in') || _isTypeCompleted('check_out')) {
      return false;
    }

    final DateTime? deadlineAt = _getCheckOutScanDeadlineTime();
    if (deadlineAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(deadlineAt);
  }

  bool get isAttendanceScanBlockedByDeadline {
    if (_isTypeCompleted('check_out')) {
      return false;
    }

    final DateTime? deadlineAt = _getCheckOutScanDeadlineTime();
    if (deadlineAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(deadlineAt);
  }

  bool get isTodayOfficeHoliday {
    final String todayKey = _todayDateKey;
    if (todayKey.isEmpty) {
      return false;
    }

    final Map<String, dynamic> policy = _asStringKeyMap(
      _officeConfigData['policy'],
    );
    final List<dynamic> holidays = <dynamic>[
      ...((_officeConfigData['holidays'] as List?) ?? const <dynamic>[]),
      ...((policy['holidays'] as List?) ?? const <dynamic>[]),
    ];

    for (final dynamic item in holidays) {
      final String? holidayDateKey = _extractHolidayDateKey(item);
      if (holidayDateKey == todayKey) {
        return true;
      }
    }
    return false;
  }

  bool get isAttendanceScanDisabled =>
      isTodayOfficeHoliday || isAttendanceScanBlockedByDeadline;

  bool get shouldShowCheckOutDeadlineCard =>
      !isTodayOfficeHoliday &&
      !hasMockScanSuccess &&
      isCheckOutScanDeadlineReached;

  String get checkOutDeadlineLabel {
    final DateTime? deadlineAt = _getCheckOutScanDeadlineTime();
    if (deadlineAt == null) {
      return '--:--';
    }
    return _formatDateTimeTo12Hour(deadlineAt);
  }

  String get selectedAttendanceScanLabel =>
      selectedAttendanceScanType == 'check_in'
      ? AppStrings.tr('check_in')
      : AppStrings.tr('check_out');

  String get lastAttendanceScanLabel => lastMockScanType == 'check_in'
      ? AppStrings.tr('check_in')
      : AppStrings.tr('check_out');

  String get selectedAttendanceActionText => isScanCooldownActive
      ? '${AppStrings.tr('wait')} ${_formatCooldownDuration(checkOutCooldownSeconds)}'
      : isTodayOfficeHoliday
      ? AppStrings.tr('holiday_today')
      : isAttendanceScanBlockedByDeadline
      ? '${AppStrings.tr('check_out')} ${AppStrings.tr('deadline_passed')}'
      : isSelectedScanCompleted
      ? '$selectedAttendanceScanLabel ${AppStrings.tr('scan_success')}'
      : selectedAttendanceScanType == 'check_in'
      ? '${AppStrings.tr('ready_to_scan')} ${AppStrings.tr('check_in')}'
      : '${AppStrings.tr('ready_to_scan')} ${AppStrings.tr('check_out')}';

  String get lateStartTimeLabel {
    final DateTime? lateThreshold = _getLateCheckInThreshold();
    if (lateThreshold == null) {
      return '--:--';
    }
    return _formatDateTimeTo12Hour(lateThreshold);
  }

  bool _isTypeCompleted(String type) {
    final attendance = currentAttendance;
    final value = type == 'check_in'
        ? attendance['check_in']
        : attendance['check_out'];

    if (value == null) return false;
    if (value is! String) return false;

    final normalized = value.trim();
    return normalized.isNotEmpty && normalized != '--:--';
  }

  String _formatCooldownDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final List<String> parts = [];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0) parts.add('${seconds}s');

    return parts.isNotEmpty ? parts.join(' ') : '0s';
  }

  void _startCheckOutCooldown({required int initialSeconds}) {
    _checkOutCooldownTimer?.cancel();
    checkOutCooldownSeconds = initialSeconds;

    if (checkOutCooldownSeconds <= 0) {
      checkOutCooldownSeconds = 0;
      return;
    }

    _checkOutCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (checkOutCooldownSeconds > 0) {
          checkOutCooldownSeconds--;
        }
      });

      if (checkOutCooldownSeconds <= 0) {
        checkOutCooldownSeconds = 0;
        timer.cancel();
      }
    });
  }

  void _stopCheckOutCooldown() {
    _checkOutCooldownTimer?.cancel();
    _checkOutCooldownTimer = null;
    checkOutCooldownSeconds = 0;
  }

  DateTime? _getCompletedTypeTime(String type) {
    final dynamic value = type == 'check_in'
        ? currentAttendance['check_in']
        : currentAttendance['check_out'];
    if (value is! String) return null;
    return _parse12hTime(value);
  }

  int _getRemainingCheckOutCooldownSeconds(DateTime checkInAt) {
    final DateTime? checkOutUnlockAt = _getCheckOutUnlockTime();
    if (checkOutUnlockAt == null) {
      return 0;
    }

    if (!checkOutUnlockAt.isAfter(checkInAt)) {
      return 0;
    }

    final int remaining = checkOutUnlockAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) return 0;
    return remaining;
  }

  DateTime? _getCheckOutUnlockTime() {
    final DateTime? checkOutEnd = _parse12hTime(officeCheckOutTime);
    if (checkOutEnd == null) {
      return null;
    }

    return checkOutEnd.subtract(Duration(minutes: checkOutScanAllowMinutes));
  }

  DateTime? _getLateCheckInThreshold() {
    final DateTime? checkInStart = _parse12hTime(officeCheckInTime);
    if (checkInStart == null) {
      return null;
    }
    return checkInStart.add(Duration(minutes: lateBufferMinutes));
  }

  void _syncCheckOutCooldownFromCheckIn(DateTime? checkInAt) {
    if (checkInAt == null) {
      _stopCheckOutCooldown();
      return;
    }

    final int remainingSeconds = _getRemainingCheckOutCooldownSeconds(
      checkInAt,
    );
    if (remainingSeconds <= 0) {
      _stopCheckOutCooldown();
      return;
    }

    _startCheckOutCooldown(initialSeconds: remainingSeconds);
  }

  DateTime? _getCheckOutScanDeadlineTime() {
    final DateTime? checkOutEnd = _parse12hTime(officeCheckOutTime);
    if (checkOutEnd == null || deadlineScanMinutes <= 0) {
      return null;
    }

    return checkOutEnd.add(Duration(minutes: deadlineScanMinutes));
  }

  void _syncDeadlineRefreshWatcher() {
    final bool shouldWatch =
        !_isTypeCompleted('check_out') &&
        _getCheckOutScanDeadlineTime() != null;

    if (!shouldWatch) {
      _stopDeadlineRefreshWatcher();
      return;
    }

    if (_deadlineRefreshTimer != null) {
      return;
    }

    _deadlineRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        _stopDeadlineRefreshWatcher();
        return;
      }

      setState(() {
        if (isAttendanceScanBlockedByDeadline) {
          _stopDeadlineRefreshWatcher();
        }
      });
    });
  }

  void _stopDeadlineRefreshWatcher() {
    _deadlineRefreshTimer?.cancel();
    _deadlineRefreshTimer = null;
  }

  String get _todayDateKey {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String? _extractHolidayDateKey(dynamic holidayItem) {
    DateTime? parsedDate;

    if (holidayItem is String) {
      parsedDate = DateTime.tryParse(holidayItem.trim());
    } else if (holidayItem is DateTime) {
      parsedDate = holidayItem;
    } else if (holidayItem is Map) {
      final Map<String, dynamic> item = _asStringKeyMap(holidayItem);
      final dynamic rawDate =
          item['date_string'] ??
          item['dateString'] ??
          item['date'] ??
          item['holiday_date'] ??
          item['holidayDate'];

      if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate.trim());
      } else if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else {
        try {
          final dynamic converted = (rawDate as dynamic).toDate();
          if (converted is DateTime) {
            parsedDate = converted;
          }
        } catch (_) {
          parsedDate = null;
        }
      }
    }

    if (parsedDate == null) {
      return null;
    }

    return '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
  }

  void applyMockAttendanceScan() {
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final formattedTime = "$hour12:$minute $period";

    if (mounted) {
      setState(() {
        if (selectedAttendanceScanType == 'check_in') {
          overrideCheckInTime = formattedTime;
        } else {
          overrideCheckOutTime = formattedTime;
        }

        final String? effectiveCheckIn = _resolveEffectiveTime('check_in');
        final String? effectiveCheckOut = _resolveEffectiveTime('check_out');
        overrideTotalHours = _calculateWorkingHours(
          effectiveCheckIn,
          effectiveCheckOut,
        );
      });
    }
  }

  String? _resolveEffectiveTime(String type) {
    if (type == 'check_in') {
      if (overrideCheckInTime != null) return overrideCheckInTime;
      final dynamic checkIn = currentAttendance['check_in'];
      if (checkIn is String && _parse12hTime(checkIn) != null) return checkIn;
      return null;
    }

    if (type == 'check_out') {
      if (overrideCheckOutTime != null) return overrideCheckOutTime;
      final dynamic checkOut = currentAttendance['check_out'];
      if (checkOut is String && _parse12hTime(checkOut) != null) {
        return checkOut;
      }
      return null;
    }

    return null;
  }

  double? _calculateWorkingHours(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null) return null;

    final DateTime? inTime = _parse12hTime(checkIn);
    final DateTime? outTime = _parse12hTime(checkOut);
    if (inTime == null || outTime == null) return null;

    Duration diff = outTime.difference(inTime);
    if (diff.isNegative) {
      diff = const Duration();
    }

    return double.parse((diff.inMinutes / 60).toStringAsFixed(1));
  }

  DateTime? _parse12hTime(String value) {
    try {
      final String normalized = value.trim();
      if (normalized.isEmpty || normalized == '--:--') return null;

      int hour;
      int minute;

      final List<String> parts = normalized.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final List<String> hm = parts[0].split(':');
        if (hm.length != 2) return null;

        hour = int.parse(hm[0]);
        minute = int.parse(hm[1]);
        final String period = parts[1].toUpperCase();

        if (period != 'AM' && period != 'PM') return null;
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
      } else {
        final List<String> hm = normalized.split(':');
        if (hm.length != 2) return null;

        hour = int.parse(hm[0]);
        minute = int.parse(hm[1]);
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return null;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTimeTo12Hour(DateTime value) {
    final int hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final String minute = value.minute.toString().padLeft(2, '0');
    final String period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateMapStyle(context);
  }

  @override
  void dispose() {
    _checkOutCooldownTimer?.cancel();
    _deadlineRefreshTimer?.cancel();
    positionStreamSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  double _toDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> _asStringKeyMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  dynamic _readByKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (source.containsKey(key)) {
        return source[key];
      }
    }
    return null;
  }

  String _readStringByKeys(
    Map<String, dynamic> source,
    List<String> keys, {
    required String fallback,
  }) {
    final dynamic raw = _readByKeys(source, keys);
    final String parsed = raw?.toString().trim() ?? '';
    return parsed.isNotEmpty ? parsed : fallback;
  }

  LatLng _resolveOfficeLocation() {
    const double fallbackLat = 11.555979932235482;
    const double fallbackLng = 104.91655648374156;

    final Map<String, dynamic> rootCenter = _asStringKeyMap(
      _officeConfigData['center'],
    );
    final Map<String, dynamic> rootLegacyLatLng = _asStringKeyMap(
      _officeConfigData['lat_lng'] ??
          _officeConfigData['latLng'] ??
          _officeConfigData['location'],
    );

    final Map<String, dynamic> geofence = _asStringKeyMap(
      _officeConfigData['geofence'],
    );
    final Map<String, dynamic> geofenceCenter = _asStringKeyMap(
      geofence['center'],
    );
    final Map<String, dynamic> geofenceLegacyLatLng = _asStringKeyMap(
      geofence['lat_lng'] ?? geofence['latLng'] ?? geofence['location'],
    );

    final double latitude = _toDouble(
      _readByKeys(rootCenter, const ['lat', 'latitude']) ??
          _readByKeys(rootLegacyLatLng, const ['lat', 'latitude']) ??
          _readByKeys(geofenceCenter, const ['lat', 'latitude']) ??
          _readByKeys(geofenceLegacyLatLng, const ['lat', 'latitude']) ??
          _readByKeys(_officeConfigData, const [
            'lat',
            'latitude',
            'office_latitude',
          ]),
      fallback: fallbackLat,
    );

    final double longitude = _toDouble(
      _readByKeys(rootCenter, const ['lng', 'longitude']) ??
          _readByKeys(rootLegacyLatLng, const ['lng', 'longitude']) ??
          _readByKeys(geofenceCenter, const ['lng', 'longitude']) ??
          _readByKeys(geofenceLegacyLatLng, const ['lng', 'longitude']) ??
          _readByKeys(_officeConfigData, const [
            'lng',
            'longitude',
            'office_longitude',
          ]),
      fallback: fallbackLng,
    );

    return LatLng(latitude, longitude);
  }

  int _parsePositiveInt(dynamic raw, {required int fallback}) {
    final int parsed = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? fallback;
    return parsed > 0 ? parsed : fallback;
  }

  int _parseNonNegativeInt(dynamic raw, {int fallback = 0}) {
    final int parsed = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? fallback;
    return parsed >= 0 ? parsed : fallback;
  }

  void updateMapStyle(BuildContext context) {
    if (mapController == null) return;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    mapController!.setMapStyle(isDarkMode ? MapStyles.dark : null);
  }

  Future<BitmapDescriptor> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return BitmapDescriptor.fromBytes(
      (await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List(),
    );
  }

  Future<void> setupOfficeMapObjects() async {
    try {
      final BitmapDescriptor customIcon = await getBytesFromAsset(
        AppImg.pinIcon,
        100,
      );
      setState(() {
        markers.clear();
        circles.clear();

        markers.add(
          Marker(
            markerId: const MarkerId('office_center'),
            position: officeLocation,
            infoWindow: InfoWindow(title: officeName),
            icon: customIcon,
            anchor: const Offset(0.5, 0.5),
          ),
        );
        circles.add(
          Circle(
            circleId: const CircleId('office_zone'),
            center: officeLocation,
            radius: scanRangeMeters,
            fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            strokeColor: Theme.of(context).colorScheme.primary,
            strokeWidth: 2,
          ),
        );
      });
    } catch (e) {
      debugPrint("Error loading map pin asset: $e");
    }
  }

  Future<void> generateProfileMarker() async {
    try {
      const double size = 120.0;
      const double radius = size / 2;
      const Color markerColor = Color(0xFF4285F4);

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);

      final Paint fillPaint = Paint()
        ..color = markerColor
        ..style = PaintingStyle.fill;
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;

      canvas.drawCircle(const Offset(radius, radius), radius - 3, fillPaint);
      canvas.drawCircle(const Offset(radius, radius), radius - 3, borderPaint);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: _userLocationMarkerTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final Offset textOffset = Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);

      final ui.Image markerImage = await pictureRecorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final ByteData? byteData = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        setState(() {
          userProfileIcon = BitmapDescriptor.fromBytes(
            byteData.buffer.asUint8List(),
          );
        });
        refreshUserMarker();
      }
    } catch (e) {
      debugPrint("Error generating user marker: $e");
    }
  }

  Future<void> initLocationTracking({
    bool skipPermissionRequest = false,
  }) async {
    if (!skipPermissionRequest) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => rangeStatusText = AppStrings.tr('perm_needed'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => rangeStatusText = AppStrings.tr('enable_loc_settings'));
        return;
      }
    }

    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      updateMapState(initialPosition);
    } catch (e) {
      debugPrint("Location service error: $e");
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) => updateMapState(position),
          onError: (e) =>
              setState(() => rangeStatusText = AppStrings.tr('waiting_loc')),
        );
  }

  void refreshUserMarker() {
    if (lastKnownPosition != null) {
      updateMapState(lastKnownPosition!);
    }
  }

  Future<void> openDirections() async {
    final lat = officeLocation.latitude;
    final lng = officeLocation.longitude;
    final Uri url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch $url");
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }

  void updateMapState(Position userPos) {
    lastKnownPosition = userPos;

    if (userPos.isMocked) {
      if (mounted) {
        setState(() {
          isInRange = false;
          isDeveloperModeDetected = true;
          rangeStatusText = AppStrings.tr('mock_gps_label');
          markers = {};
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.tr('developer_mode_alert_message'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (!_developerModeWarningShown) {
        _developerModeWarningShown = true;
        _showDeveloperModeWarningAndExit(
          message: AppStrings.tr('developer_mode_alert_message'),
        );
      }
      return;
    }

    double distance = Geolocator.distanceBetween(
      userPos.latitude,
      userPos.longitude,
      officeLocation.latitude,
      officeLocation.longitude,
    );

    bool inScanRange = distance <= scanRangeMeters;

    Marker userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(userPos.latitude, userPos.longitude),
      icon:
          userProfileIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: _userLocationMarkerTitle),
      zIndex: 2,
    );

    Set<Marker> newMarkers = Set.from(markers);
    newMarkers.removeWhere((m) => m.markerId.value == 'user_location');
    newMarkers.add(userMarker);

    if (mounted) {
      setState(() {
        isInRange = inScanRange;
        rangeStatusText = inScanRange
            ? AppStrings.tr('in_office_area')
            : "${AppStrings.tr('far_from_office')} ${distance.toStringAsFixed(0)}m";
        markers = newMarkers;
      });

      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(userPos.latitude, userPos.longitude),
            zoom: 18,
            tilt: 0,
          ),
        ),
      );
    }
  }

  void markMockScanSuccess() {
    if (mounted) {
      setState(() {
        final String scannedType = selectedAttendanceScanType;
        lastMockScanType = scannedType;

        lastMockScanAt = _getCompletedTypeTime(scannedType);

        final bool isCompleted = _isTypeCompleted(scannedType);
        attendanceScanStatus[scannedType] = isCompleted;
        attendanceScanSuccessAt[scannedType] = lastMockScanAt;

        if (scannedType == 'check_in' &&
            !(attendanceScanStatus['check_out'] ?? false)) {
          selectedAttendanceScanType = 'check_out';
          hasMockScanSuccess = false;
          lastMockScanAt = null;
          final DateTime? checkInAt = _getCompletedTypeTime('check_in');
          _syncCheckOutCooldownFromCheckIn(checkInAt);
        } else {
          hasMockScanSuccess = isCompleted;

          if (scannedType == 'check_out' && isCompleted) {
            _stopCheckOutCooldown();
          }
        }
      });
    }
  }

  void applyDatabaseAttendanceScan(Map<String, dynamic> savedRecord) {
    final Map<String, dynamic> normalizedRecord = Map<String, dynamic>.from(
      savedRecord,
    );
    final String uid = (normalizedRecord['uid'] ?? currentUser.id)
        .toString()
        .trim();
    final String dateKey =
        (normalizedRecord['date'] ?? currentAttendance['date'])
            .toString()
            .trim();

    if (uid.isEmpty || dateKey.isEmpty) {
      return;
    }

    final int existingIndex = attendanceRecords.indexWhere(
      (record) =>
          record['uid']?.toString() == uid &&
          record['date']?.toString() == dateKey,
    );

    final Map<String, dynamic> mergedRecord = {
      if (existingIndex >= 0) ...attendanceRecords[existingIndex],
      ...normalizedRecord,
      'uid': uid,
      'date': dateKey,
    };

    if (existingIndex >= 0) {
      attendanceRecords[existingIndex] = mergedRecord;
    } else {
      attendanceRecords.add(mergedRecord);
    }

    if (!mounted) return;

    setState(() {
      overrideCheckInTime = null;
      overrideCheckOutTime = null;
      overrideTotalHours = null;
      _syncScanStateFromAttendanceData();
    });
  }

  void resetMockScanSuccess() {
    if (mounted) {
      setState(() {
        hasMockScanSuccess = false;
      });
    }
  }
}

abstract class WorkspaceScreenLogic extends State<WorkspaceScreen> {
  late final WorkspaceRepository _workspaceRepo;
  late final UserRepository _userRepo;
  bool isConfirming = false;
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

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await _loadFromLocal();

    if (!mounted) return;

    final bool hasAnyLocalData = hasLocalUser || hasLocalWorkspaces;

    if (hasAnyLocalData) {
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
      } catch (e) {
        debugPrint(
          '⛔ [WorkspaceScreenLogic] Error parsing cached workspaces: $e',
        );
      }
    }

    final cachedUserJson = prefs.getString(_cacheKeyUser);
    if (cachedUserJson != null) {
      try {
        currentUser = UserModel.fromJson(jsonDecode(cachedUserJson));
      } catch (e) {
        debugPrint('⛔ [WorkspaceScreenLogic] Error parsing cached user: $e');
      }
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
      } catch (e) {
        debugPrint(
          '⛔ [WorkspaceScreenLogic] Error loading user profile from DB: $e',
        );
      }
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
      debugPrint(
        '⛔ [WorkspaceScreenLogic] Error parsing user from loginData: $e',
      );
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

  Future<void> onConfirmSelection() async {
    if (selectedWorkspaceId == null) return;

    // Trigger the skeleton loader on your Workspace Screen UI
    setState(() {
      isConfirming = true;
    });

    // Await the confirmation/navigation
    widget.onWorkspaceConfirmed(selectedWorkspaceId!);

    if (mounted) {
      setState(() {
        isConfirming = false;
      });
    }
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
