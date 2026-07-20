import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/attendance_stats_screen.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/attendance_record.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';

abstract class AttendanceStatsLogic extends State<AttendanceStatsScreen> {
  late UserProfile currentUser;
  late List<AttendanceRecord> userAttendanceRecords;
  late List<Map<String, dynamic>> monthlyStats = [];
  late String? loggedInUserId;

  bool animateChart = false;
  String selectedFilter = 'All';
  late int selectedMonthIndex = 0;
  late int selectedYear;
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();
  bool isLoading = true;

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
    _loadData().then((_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => animateChart = true);
          }
        });
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

  Future<void> _loadData() async {
    try {
      final users = await _realtimeDataController.fetchUserRecords();
      final attendanceRecords = await _realtimeDataController
          .fetchAttendanceRecords();

      final currentUserData = users.firstWhere(
        (user) =>
            (user['uid'] ?? user['user_id'] ?? user['userId'])
                ?.toString()
                .trim() ==
            (loggedInUserId ?? _resolveUserId()),
        orElse: () => defaultUserRecord,
      );

      currentUser = UserProfile.fromJson(currentUserData);

      userAttendanceRecords = attendanceRecords
          .where((record) => record['uid'] == currentUser.uid)
          .map((json) => AttendanceRecord.fromJson(json))
          .toList();

      final now = DateTime.now();
      selectedYear = now.year;
      monthlyStats = [];

      for (int i = 4; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);

        monthlyStats.add({
          "monthKey": monthKeys[date.month],
          "year": date.year,
          "percentage": _calculateMonthlyPercentage(date),
          "present": _countByStatus(date, 'on_time'),
          "late": _countByStatus(date, 'late'),
          "absent": _countByStatus(date, 'absent'),
        });
      }

      selectedMonthIndex = monthlyStats.isNotEmpty
          ? monthlyStats.length - 1
          : 0;
    } catch (e) {
      debugPrint("Load error: $e");
    }

    setState(() {
      isLoading = false; 
    });
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
