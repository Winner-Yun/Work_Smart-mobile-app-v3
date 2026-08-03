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
      fallback: 50,
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

      // Scoped per workspace (like the policy cache below) — otherwise
      // switching to a workspace that has no geofence cached of its own
      // would silently pick up whichever *other* workspace's geofence
      // happened to be sitting under this key last, instead of showing
      // "no geofence yet" until the background fetch resolves the real one.
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
    } catch (e) {
      debugPrint('[_loadLocalWorkspaceAndConfig] Error: $e');
    }
  }

  // Pure data fetch — no isRefreshing/isInitialDataLoading side effects.
  // Every caller controls the loading flag around its *whole* sequence of
  // awaited calls (see onRefresh/_loadAllData below); this used to flip
  // isRefreshing off in its own `finally` block as soon as *it* finished,
  // which hid the skeleton loader while callers still had more awaits left
  // (e.g. onRefresh's _loadData/_fetchMyAttendance/setupOfficeMapObjects),
  // so the UI would flash partially-loaded content before the refresh
  // actually completed.
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
            'status': fetchedPolicy.status,
          };
          _officeConfigData['policy'] = policyMap;

          // Skip the write entirely when the fetched policy is byte-for-byte
          // identical to what's already cached — this runs on every
          // homepage load and every pull-to-refresh, so writing unchanged
          // data each time is a wasted disk write for no benefit.
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
      }
    } catch (e) {
      debugPrint('[_fetchWorkspaceGeofenceAndPolicy] Error: $e');
    }
  }

  Future<void> onRefresh() async {
    // Manual refresh swaps the whole page for the same skeleton loader used
    // on initial load (see homepagescreen.dart's build, gated on
    // isManualRefreshing) instead of a modal dialog over stale content.
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
    } catch (e) {
      debugPrint('[onRefresh] Error: $e');
    } finally {
      // Must always clear both flags, even on failure — _onScroll only
      // allows another pull-to-refresh while isRefreshing is false, so
      // leaving either set here permanently locks the homepage.
      if (mounted) {
        setState(() {
          isRefreshing = false;
          isManualRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadAllData() async {
    // Profile is read from local cache only here — no network round trip.
    // The network fetch+save (_fetchAndSaveUserProfile) only runs on
    // explicit pull-to-refresh (see onRefresh below); profile edits already
    // save to local DB immediately (profile_screens.dart), so the next
    // homepage load just picks up the cached copy. Without this, every tab
    // switch back to Home recreated HomePageLogic's state and re-fetched the
    // profile from the server, adding a network round trip to every visit.
    await _loadLocalWorkspaceAndConfig();
    await _loadData();

    // Keep the skeleton up briefly even though the local load was fast, so
    // loading doesn't read as a jarring instant pop-in.
    await Future.delayed(AppDurations.minSkeletonDisplay);
    if (!mounted) return;

    setState(() {
      isInitialDataLoading = false;
    });

    // Background refinement pass (server-sourced profile/workspace/geofence/
    // policy, re-applied attendance, map objects). Re-fetching the profile
    // here (same as onRefresh) means a name/avatar change made elsewhere
    // (e.g. another device, or an admin edit) shows up on the next homepage
    // visit without the user needing to pull-to-refresh manually.
    // isRefreshing must always get cleared here even on failure —
    // _onScroll only allows a pull-to-refresh while isRefreshing is false,
    // so an uncaught error here would otherwise permanently disable
    // pull-to-refresh from the very first homepage load.
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
    } catch (e) {
      debugPrint('[_loadAllData] background refresh error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  /// Public entry point for callers outside this library (e.g. the homepage
  /// screen after a face scan returns) to re-sync attendance from the
  /// backend in place, without navigating away. Shows the same skeleton
  /// loader used by pull-to-refresh while the request is in flight.
  Future<void> refreshAttendanceFromServer() async {
    if (mounted) {
      setState(() {
        isRefreshing = true;
      });
    }

    await _fetchMyAttendance();

    if (mounted) {
      setState(() {
        isRefreshing = false;
      });
    }
  }

  /// Pulls the current user's *today* attendance for the active workspace
  /// from the backend and replaces the shared in-memory `attendanceRecords`
  /// list that `currentAttendance` (see attendance_scan_mixin.dart) reads
  /// from. Scoped to today via `date_filter=today` so the homepage doesn't
  /// have to page through the user's whole history just to know whether
  /// they've checked in/out today.
  Future<void> _fetchMyAttendance() async {
    final String? workspaceId = currentWorkspace?.id;
    if (workspaceId == null || workspaceId.isEmpty) return;

    try {
      final AttendanceModel? today = await _attendanceRepo.getTodayAttendance(
        workspaceId,
      );
      final String uid = currentUser.id;
      setAttendanceRecords(
        today == null
            ? <Map<String, dynamic>>[]
            : [today.toLegacyMap()..['uid'] = uid],
      );

      if (mounted) {
        setState(_syncScanStateFromAttendanceData);
      }
    } catch (e) {
      debugPrint('[_fetchMyAttendance] Error: $e');
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
