import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/repository/attendance_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/attendance_service.dart';
import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/attendance_stats_screen.dart';
import 'package:flutter_worksmart_app/shared/model/attendance_model.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AttendanceStatsLogic extends State<AttendanceStatsScreen> {
  late UserModel currentUser;
  List<AttendanceModel> userAttendanceRecords = [];
  late List<Map<String, dynamic>> monthlyStats = [];
  late String? loggedInUserId;

  bool animateChart = false;
  String selectedFilter = 'All';
  late int selectedMonthIndex = 0;
  late int selectedYear;
  final AttendanceRepository _attendanceRepo = AttendanceRepository(
    AttendanceService(),
  );
  bool isLoading = true;
  bool isRefreshing = false;

  String _workspaceId = '';
  SharedPreferences? _prefs;

  String get _cacheKey => 'cached_attendance_stats_$_workspaceId';

  final List<String> monthKeys = [
    '',
    'month_jan',
    'month_feb',
    'month_mar',
    'month_apr',
    'month_may',
    'month_jun',
    'month_jul',
    'month_aug',
    'month_sep',
    'month_oct',
    'month_nov',
    'month_dec',
  ];

  @override
  void initState() {
    super.initState();
    loggedInUserId = _resolveUserId();
    _initData();
  }

  void _triggerChartAnimation() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => animateChart = true);
      }
    });
  }

  String _resolveUserId() {
    return (widget.loginData?['uid'] ??
            widget.loginData?['user_id'] ??
            widget.loginData?['userId'] ??
            '')
        .toString()
        .trim();
  }

  /// REST profile, falling back to the local cache if the network call fails.
  Future<UserModel> _resolveCurrentUser() async {
    try {
      return await UserRepository(UserService()).getUserProfile();
    } catch (_) {
      final cached = await DatabaseHelper().getUserProfile();
      return UserModel.fromJson(cached ?? const <String, dynamic>{});
    }
  }

  /// Local-first init: show cached attendance instantly, refresh in the background,
  /// and only block with the skeleton loader on a true cold start.
  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _workspaceId = _prefs!.getString('selected_workspace_id') ?? '';

    await _loadFromLocal();
    if (!mounted) return;

    if (userAttendanceRecords.isNotEmpty) {
      // Keep the skeleton up briefly so an instant cache read doesn't pop in jarringly.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (!mounted) return;
      setState(() {
        _recomputeStats();
        isLoading = false;
      });
      _triggerChartAnimation();
      _fetchFromNetwork(showLoading: false);
    } else {
      await _fetchFromNetwork(showLoading: true);
      _triggerChartAnimation();
    }
  }

  Future<void> _loadFromLocal() async {
    final prefs = _prefs;
    if (prefs == null || _workspaceId.isEmpty) return;

    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      userAttendanceRecords = decoded
          .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _fetchFromNetwork({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final resolvedUser = await _resolveCurrentUser();

      final fetchedRecords = _workspaceId.isEmpty
          ? <AttendanceModel>[]
          : await _attendanceRepo.getMyAttendance(
              _workspaceId,
              sortBy: 'date',
              sortOrder: 'desc',
              limit: 500,
            );

      if (!mounted) return;

      final bool changed = _hasAttendanceChanged(fetchedRecords);

      setState(() {
        currentUser = resolvedUser;
        if (changed) {
          userAttendanceRecords = fetchedRecords;
        }
        _recomputeStats();
        isLoading = false;
      });

      if (changed) {
        await _saveToCache(fetchedRecords);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  bool _hasAttendanceChanged(List<AttendanceModel> fetched) {
    final String fetchedJson = jsonEncode(
      fetched.map((e) => e.toJson()).toList(),
    );
    final String currentJson = jsonEncode(
      userAttendanceRecords.map((e) => e.toJson()).toList(),
    );
    return fetchedJson != currentJson;
  }

  Future<void> _saveToCache(List<AttendanceModel> records) async {
    final prefs = _prefs;
    if (prefs == null || _workspaceId.isEmpty) return;
    try {
      await prefs.setString(
        _cacheKey,
        jsonEncode(records.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Recomputes monthlyStats/selectedYear/selectedMonthIndex from userAttendanceRecords.
  void _recomputeStats() {
    final now = DateTime.now();
    selectedYear = now.year;
    final newStats = <Map<String, dynamic>>[];

    for (int i = 4; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);

      newStats.add({
        "monthKey": monthKeys[date.month],
        "year": date.year,
        "percentage": _calculateMonthlyPercentage(date),
        "present": _countByStatus(date, 'on_time'),
        "late": _countByStatus(date, 'late'),
        "absent": _countByStatus(date, 'absent'),
      });
    }

    monthlyStats = newStats;
    selectedMonthIndex = monthlyStats.isNotEmpty
        ? monthlyStats.length - 1
        : 0;
  }

  /// Manual pull-to-refresh — always hits the network and updates the cache on success.
  Future<void> onRefresh() async {
    if (isRefreshing || !mounted) return;
    setState(() => isRefreshing = true);

    try {
      await _fetchFromNetwork(showLoading: false);
    } catch (_) {} finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  /// Calculate monthly attendance percentage based on records
  /// Returns: (present + late) / total records for that month
  double _calculateMonthlyPercentage(DateTime month) {
    final monthRecords = userAttendanceRecords.where((r) {
      final recordDate = DateTime.parse(r.date);
      return recordDate.year == month.year && recordDate.month == month.month;
    }).toList();

    if (monthRecords.isEmpty) return 0.0;

    // Count: present (on_time) + late = attended
    final attendedCount = monthRecords
        .where((r) => r.status == 'on_time' || r.status == 'late')
        .length;

    // Percentage = attended / total records
    return attendedCount / monthRecords.length;
  }

  /// Count attendance by status for a specific month
  int _countByStatus(DateTime month, String status) {
    return userAttendanceRecords.where((r) {
      final recordDate = DateTime.parse(r.date);
      return recordDate.year == month.year &&
          recordDate.month == month.month &&
          r.status == status;
    }).length;
  }

  /// Get attendance records for history display
  List<Map<String, dynamic>> getAttendanceHistoryData() {
    return userAttendanceRecords.map((record) {
      final date = DateTime.parse(record.date);
      final dayName = _getDayName(date.weekday);

      return {
        "date": "${date.day} ${_getMonthName(date.month)} ${date.year}",
        "month": date.month,
        "year": date.year,
        "day": dayName,
        "status": record.status,
        "color": record.status == 'on_time'
            ? Colors.green
            : record.status == 'late'
            ? Colors.orange
            : Colors.red,
        "checkIn": record.checkIn,
        "checkOut": record.checkOut,
        "hours": _formatHours(record.totalHours),
        "isLate": record.status == 'late',
      };
    }).toList();
  }

  /// Get filtered attendance records
  List<Map<String, dynamic>> getFilteredAttendanceData() {
    final allData = getAttendanceHistoryData();

    // Prevent access if data not ready
    if (monthlyStats.isEmpty) {
      return [];
    }

    // Clamp selectedMonthIndex to valid range
    final safeIndex = selectedMonthIndex.clamp(0, monthlyStats.length - 1);

    final activeMonth = monthlyStats[safeIndex];
    final activeYear = activeMonth['year'] as int;
    final activeMonthKey = activeMonth['monthKey'] as String;
    final activeMonthIndex = monthKeys.indexOf(activeMonthKey);

    // Skip if month key is invalid (empty string returns 0)
    if (activeMonthIndex <= 0) {
      return [];
    }

    final monthData = allData.where((e) {
      return e['year'] == activeYear && e['month'] == activeMonthIndex;
    }).toList();

    if (selectedFilter == 'All') return monthData;
    if (selectedFilter == 'Late') {
      return monthData.where((e) => e['isLate'] == true).toList();
    }
    if (selectedFilter == 'Absent') {
      return monthData.where((e) => e['status'] == 'absent').toList();
    }
    return monthData;
  }

  String _getDayName(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatHours(double hours) {
    final hourPart = hours.toInt();
    final minutePart = ((hours - hourPart) * 60).toInt();

    if (minutePart == 0) {
      return '${hourPart}h';
    }
    return '${hourPart}h ${minutePart}m';
  }
}
