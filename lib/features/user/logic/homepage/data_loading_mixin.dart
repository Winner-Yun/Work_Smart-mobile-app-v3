part of '../homepage_logic.dart';

mixin _DataLoadingMixin
    on
        _HomePageLogicState,
        _AttendanceScanMixin,
        _MapLocationMixin,
        _FaceEmbeddingMixin {
  Future<Map<String, dynamic>?> _loadCachedUserProfile() async {
    try {
      return await DatabaseHelper().getUserProfile();
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchAndSaveUserProfile() async {
    try {
      final userRepository = UserRepository(UserService());
      final UserModel userModel = await userRepository.getUserProfile();
      final Map<String, dynamic> userJson = userModel.toJson();
      await DatabaseHelper().saveUserProfile(userJson);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final Map<String, dynamic> effectiveUserData =
        await _loadCachedUserProfile() ?? <String, dynamic>{};

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

    officeLocation = _resolveOfficeLocation();

    final geofence =
        (_officeConfigData['geofence'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    scanRangeMeters = _toDouble(
      geofence['radius_meters'] ??
          geofence['radiusMeters'] ??
          geofence['radius'],
      fallback: 0,
    );
    if (currentWorkspace != null &&
        currentWorkspace!.workspaceName.isNotEmpty) {
      officeName = currentWorkspace!.workspaceName;
    } else if (currentGeofence != null && currentGeofence!.name.isNotEmpty) {
      officeName = currentGeofence!.name;
    } else {
      officeName =
          _officeConfigData['office_name']?.toString() ??
          AppStrings.tr('main_office');
    }

    final Map<String, dynamic> policy = _asStringKeyMap(
      _officeConfigData['policy'],
    );
    officeCheckInTime = _readStringByKeys(policy, const [
      'check_in_start',
      'checkInStart',
    ], fallback: '09:00 AM');
    officeCheckOutTime = _readStringByKeys(policy, const [
      'check_out_start',
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

    final dynamic rawRequiresCheckOut =
        _readByKeys(policy, const ['requires_check_out', 'requiresCheckOut']) ??
        _readByKeys(_officeConfigData, const [
          'requires_check_out',
          'requiresCheckOut',
        ]);
    requiresCheckOut = rawRequiresCheckOut is bool
        ? rawRequiresCheckOut
        : (rawRequiresCheckOut?.toString().toLowerCase() != 'false');
    await _loadFaceEmbeddingData();
    _syncScanStateFromAttendanceData();
  }

  Future<void> _loadLocalWorkspaceAndConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString('selected_workspace_id');

      final cachedWorkspaceJson = prefs.getString('cached_selected_workspace');
      bool hasMatchingCache = false;

      //  Check if the cached active workspace matches the newly selected ID
      if (cachedWorkspaceJson != null) {
        final cachedWs = Workspace.fromJson(jsonDecode(cachedWorkspaceJson));
        if (selectedId == null || cachedWs.id == selectedId) {
          currentWorkspace = cachedWs;
          hasMatchingCache = true;
        }
      }

      //  If it doesn't match (user switched), pull the new name instantly from the workspaces list
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

      // Scoped per workspace so switching workspaces never inherits another one's geofence.
      if (selectedId != null && selectedId.isNotEmpty) {
        final cachedGeofenceJson = prefs.getString(
          'cached_homepage_geofence_$selectedId',
        );
        if (cachedGeofenceJson != null) {
          final Map<String, dynamic> geofenceMap = jsonDecode(
            cachedGeofenceJson,
          );
          currentGeofence = GeofenceModel.fromJson(geofenceMap);
          _officeConfigData['geofence'] = geofenceMap;
        }
      }

      if (selectedId != null && selectedId.isNotEmpty) {
        final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
          selectedId,
        );
        if (cachedPolicyMap != null) {
          currentPolicy = PolicyModel.fromJson(cachedPolicyMap);
          _officeConfigData['policy'] = cachedPolicyMap;
        }
      }

      // Scoped per workspace + day so a cache from yesterday (or another
      // workspace) never gets read as if it were today's scan status.
      if (selectedId != null && selectedId.isNotEmpty) {
        final cachedAttendanceJson = prefs.getString(
          'cached_homepage_attendance_$selectedId',
        );
        if (cachedAttendanceJson != null) {
          final Map<String, dynamic> cached = jsonDecode(cachedAttendanceJson);
          final List<dynamic> rawRecords = cached['date'] == _todayDateKey
              ? ((cached['records'] as List<dynamic>?) ?? const [])
              : const [];
          setAttendanceRecords(
            rawRecords
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          );
          isAttendanceDataReady = true;
        }
      }
    } catch (_) {}
  }

  String get _todayDateKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _saveCachedTodayAttendance(
    String workspaceId,
    List<Map<String, dynamic>> records,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_homepage_attendance_$workspaceId',
        jsonEncode({'date': _todayDateKey, 'records': records}),
      );
    } catch (_) {}
  }

  // Pure data fetch, no loading-flag side effects — callers control the flag
  // around their whole await sequence so the skeleton doesn't hide too early.
  Future<void> _fetchWorkspaceGeofenceAndPolicy() async {
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
          _holidayRepo
              .getHolidayConfig(selectedWorkspaceId)
              .then((c) => c as dynamic)
              .catchError((_) => null),
          _holidayRepo
              .getHolidays(selectedWorkspaceId)
              .then((h) => h as dynamic)
              .catchError((_) => null),
        ]);

        final List<Workspace> fetchedWorkspaces = results[0] as List<Workspace>;
        final GeofenceModel? fetchedGeofence = results[1] as GeofenceModel?;
        final PolicyModel? fetchedPolicy = results[2] as PolicyModel?;
        final HolidayConfigModel? fetchedHolidayConfig =
            results[3] as HolidayConfigModel?;
        final List<HolidayModel>? fetchedHolidays =
            results[4] as List<HolidayModel>?;

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
            'cached_homepage_geofence_$selectedWorkspaceId',
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
            'requires_check_out': fetchedPolicy.requiresCheckOut,
            'status': fetchedPolicy.status,
          };
          _officeConfigData['policy'] = policyMap;

          // Skip the write when the fetched policy matches what's already cached.
          final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
            selectedWorkspaceId,
          );
          final bool policyChanged =
              cachedPolicyMap == null ||
              jsonEncode(cachedPolicyMap) != jsonEncode(policyMap);
          if (policyChanged) {
            await DatabaseHelper().saveCachedPolicy(
              selectedWorkspaceId,
              policyMap,
            );
          }
        }

        if (fetchedHolidayConfig != null) {
          currentHolidayConfig = fetchedHolidayConfig;
        }

        if (fetchedHolidays != null) {
          workspaceHolidays = fetchedHolidays;
        }
      }
    } catch (_) {}
  }

  Future<void> onRefresh() async {
    // Manual refresh reuses the same skeleton loader as initial load, not a modal dialog.
    if (!mounted) return;

    setState(() {
      isRefreshing = true;
      isManualRefreshing = true;
    });

    try {
      await _fetchAndSaveUserProfile();
      await _fetchWorkspaceGeofenceAndPolicy();
      await _loadData();
      await _fetchMyAttendance();
      await setupOfficeMapObjects();
    } catch (_) {
    } finally {
      // Must clear both flags even on failure, or pull-to-refresh locks up permanently.
      if (mounted) {
        setState(() {
          isRefreshing = false;
          isManualRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadAllData() async {
    // Profile here is cache-only (no network) — the fetch+save runs on pull-to-refresh,
    // since profile edits already save locally, so every tab visit avoids a round trip.
    await _loadLocalWorkspaceAndConfig();
    await _loadData();

    // Keep the skeleton up briefly so a fast local load doesn't pop in jarringly.
    await Future.delayed(AppDurations.minSkeletonDisplay);
    if (!mounted) return;

    setState(() {
      isInitialDataLoading = false;
    });

    // Background refinement pass so changes made elsewhere (another device, admin
    // edit) show up without a manual pull-to-refresh. Must clear isRefreshing even
    // on failure, or pull-to-refresh stays disabled from the first load onward.
    if (mounted) {
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      await _fetchAndSaveUserProfile();
      await _fetchWorkspaceGeofenceAndPolicy();
      if (mounted) {
        await _loadData();
        await _fetchMyAttendance();
        await setupOfficeMapObjects();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  /// Pulls today's attendance for the active workspace and replaces the shared
  /// in-memory `attendanceRecords` list, scoped to today so it skips paging history.
  Future<void> _fetchMyAttendance() async {
    final String? workspaceId = currentWorkspace?.id;
    if (workspaceId == null || workspaceId.isEmpty) return;

    try {
      final AttendanceModel? today = await _attendanceRepo.getTodayAttendance(
        workspaceId,
      );
      final String uid = currentUser.id;
      final List<Map<String, dynamic>> records = today == null
          ? <Map<String, dynamic>>[]
          : [today.toLegacyMap()..['uid'] = uid];
      setAttendanceRecords(records);
      await _saveCachedTodayAttendance(workspaceId, records);

      if (mounted) {
        setState(() {
          isAttendanceDataReady = true;
          _syncScanStateFromAttendanceData();
        });
      }
    } catch (_) {
      // Fail open: a network hiccup shouldn't permanently lock the scan card
      // behind the loading card. Pull-to-refresh (or the next auto refresh)
      // will retry the fetch and correct the state once it succeeds.
      if (mounted) {
        setState(() {
          isAttendanceDataReady = true;
        });
      }
    }
  }

  // --- Getters for UI Consumption ---
  String get currentUserDisplayName => currentUser.name;

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
}
