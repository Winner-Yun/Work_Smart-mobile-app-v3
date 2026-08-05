import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/constants/map_styles.dart';
import 'package:flutter_worksmart_app/core/util/database/attendance_data.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/face/face_attendance_verifier.dart';
import 'package:flutter_worksmart_app/core/util/notification/local_notification_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/homepagescreen.dart';
import 'package:flutter_worksmart_app/features/user/repository/attendance_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/face_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/geofence_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/policy_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/workspace_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/attendance_service.dart';
import 'package:flutter_worksmart_app/features/user/service/face_service.dart';
import 'package:flutter_worksmart_app/features/user/service/geofence_service.dart';
import 'package:flutter_worksmart_app/features/user/service/policy_service.dart';
import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/service/workspace_service.dart';
import 'package:flutter_worksmart_app/shared/model/attendance_model.dart';
import 'package:flutter_worksmart_app/shared/model/geofence_model.dart';
import 'package:flutter_worksmart_app/shared/model/policy_model.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'homepage/attendance_scan_mixin.dart';
part 'homepage/data_loading_mixin.dart';
part 'homepage/face_embedding_mixin.dart';
part 'homepage/map_location_mixin.dart';
part 'homepage/permission_flow_mixin.dart';

enum _PermissionResolutionAction { retry, settings, notNow }

// Holds shared state so the concern mixins below can compose onto HomePageLogic
// without a mixin being constrained on the very class it mixes into.
abstract class _HomePageLogicState extends State<HomePageScreen> {
  String get _userLocationMarkerTitle => AppStrings.tr('map_marker_me');

  // --- Repositories & Services ---
  late final GeofenceRepository _geofenceRepo;

  late final PolicyRepository _policyRepo;

  late final WorkspaceRepository _workspaceRepo;

  late final FaceRepository _faceRepo;

  late final AttendanceRepository _attendanceRepo;

  // Always set by re-reading DatabaseHelper directly — never trust a stale in-memory copy.
  bool hasLocalFaceEmbedding = false;

  bool isFaceEmbeddingUpdating = false;

  Workspace? currentWorkspace;

  GeofenceModel? currentGeofence;

  PolicyModel? currentPolicy;

  // Gates the scan card until real geofence/policy data arrives, so it never
  // checks the user in/out against fallback defaults right after a workspace switch.
  bool get isWorkspaceSetupReady => currentGeofence != null && currentPolicy != null;

  bool isRefreshing = false;

  String get workspaceName => currentWorkspace?.workspaceName.isNotEmpty == true
      ? currentWorkspace!.workspaceName
      : officeName;

  String get workspaceDescription =>
      currentWorkspace?.description.isNotEmpty == true
      ? currentWorkspace!.description
      : AppStrings.tr('no_details_provided');

  int get workspaceMemberCount => currentWorkspace?.memberCount ?? 1;

  // --- Data Models ---
  late UserModel currentUser;

  late String? loggedInUserId;

  final Map<String, dynamic> _officeConfigData = <String, dynamic>{};

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

  late bool requiresCheckOut;

  // --- UI State Tracking ---
  bool isInitialDataLoading = true;

  // Only the manual pull-to-refresh sets this — unlike `isRefreshing`, it must
  // never trigger the skeleton loader.
  bool isManualRefreshing = false;

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
}

abstract class HomePageLogic extends _HomePageLogicState
    with
        _MapLocationMixin,
        _PermissionFlowMixin,
        _FaceEmbeddingMixin,
        _AttendanceScanMixin,
        _DataLoadingMixin {
  @override
  void initState() {
    super.initState();
    _geofenceRepo = GeofenceRepository(GeofenceService());
    _policyRepo = PolicyRepository(PolicyService());
    _workspaceRepo = WorkspaceRepository(WorkspaceService());
    _faceRepo = FaceRepository(FaceService());
    _attendanceRepo = AttendanceRepository(AttendanceService());
    loggedInUserId = widget.loginData?['uid'];
    _loadAllData();
    setupOfficeMapObjects();
    generateProfileMarker();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupPermissionFlow();
      // _detectDeveloperModeOnHomepage();
    });
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
}
