import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/presentation/activity_screens/activity_feed_screen.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/activity_feed_item.dart';

enum ActivitySortOption { newest, oldest, nameAZ, nameZA }

abstract class ActivityFeedLogic extends State<ActivityFeedScreen> {
  bool isLoading = true;
  String searchQuery = '';
  ActivitySortOption sortOption = ActivitySortOption.newest;
  List<ActivityFeedItem> allFeedItems = [];
  List<ActivityFeedItem> feedItems = [];
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> refreshFeed() async {
    await _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => isLoading = true);
    final users = await _realtimeDataController.fetchUserRecords();
    final attendanceRecords = await _realtimeDataController
        .fetchAttendanceRecords();
    final currentUserId = widget.loginData?['uid']?.toString();
    final currentUser = users.firstWhere(
      (u) => u['uid']?.toString() == currentUserId,
      orElse: () => defaultUserRecord,
    );

    final currentDepartmentId = currentUser['department_id']?.toString();
    final departmentUsers = users
        .where((u) => u['department_id']?.toString() == currentDepartmentId)
        .toList();

    final userIds = departmentUsers
        .map((u) => u['uid']?.toString())
        .whereType<String>()
        .toSet();
    debugPrint('userID $userIds');

    final records =
        attendanceRecords
            .where((r) => userIds.contains(r['uid']?.toString()))
            .toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a['date']?.toString() ?? '');
            final db = DateTime.tryParse(b['date']?.toString() ?? '');
            if (da == null || db == null) return 0;
            return db.compareTo(da);
          });
    debugPrint(
      'Fetched ${records.length} attendance records for department $currentDepartmentId',
    );

    final built = <ActivityFeedItem>[];

    for (final rec in records.take(30)) {
      final uid = rec['uid']?.toString() ?? '';
      final user = users.firstWhere(
        (u) => u['uid']?.toString() == uid,
        orElse: () => {'display_name': AppStrings.tr('unknown_user')},
      );

      final name =
          user['display_name']?.toString() ?? AppStrings.tr('unknown_user');
      final status = rec['status']?.toString() ?? 'on_time';
      final checkIn = rec['check_in']?.toString();
      final checkOut = rec['check_out']?.toString();
      final totalHours = rec['total_hours'];
      final date = rec['date']?.toString() ?? '';

      final occurredAt = DateTime.tryParse(date) ?? DateTime.now();
      final scanInValue = checkIn ?? '--:--';
      final scanOutValue = checkOut ?? '--:--';
      final totalWorkTimeValue = _formatTotalWorkTime(totalHours);
      final dateLabel = _formatFullDate(date);

      if (status == 'absent') {
        built.add(
          ActivityFeedItem(
            actorName: name,
            title: _trf('activity_title_absent', {'name': name}),
            subtitle: AppStrings.tr('activity_subtitle_absent'),
            timeLabel: _formatDateLabel(date),
            dateLabel: dateLabel,
            scanIn: scanInValue,
            scanOut: scanOutValue,
            totalWorkTime: totalWorkTimeValue,
            occurredAt: occurredAt,
            icon: Icons.event_busy_rounded,
            color: Colors.red,
          ),
        );
      } else if (status == 'late') {
        built.add(
          ActivityFeedItem(
            actorName: name,
            title: _trf('activity_title_late', {'name': name}),
            subtitle: _trf('activity_subtitle_late', {
              'time': checkIn ?? '--:--',
            }),
            timeLabel: _formatDateLabel(date),
            dateLabel: dateLabel,
            scanIn: scanInValue,
            scanOut: scanOutValue,
            totalWorkTime: totalWorkTimeValue,
            occurredAt: occurredAt,
            icon: Icons.schedule_rounded,
            color: Colors.orange,
          ),
        );
      } else {
        built.add(
          ActivityFeedItem(
            actorName: name,
            title: _trf('activity_title_on_time', {'name': name}),
            subtitle: AppStrings.tr('activity_subtitle_on_time'),
            timeLabel: _formatDateLabel(date),
            dateLabel: dateLabel,
            scanIn: scanInValue,
            scanOut: scanOutValue,
            totalWorkTime: totalWorkTimeValue,
            occurredAt: occurredAt,
            icon: Icons.verified_rounded,
            color: Colors.green,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      allFeedItems = built;
      _applySearchAndSort();
      isLoading = false;
    });
  }

  void onSearchChanged(String value) {
    setState(() {
      searchQuery = value.trim();
      _applySearchAndSort();
    });
  }

  void onSortChanged(ActivitySortOption value) {
    setState(() {
      sortOption = value;
      _applySearchAndSort();
    });
  }

  void _applySearchAndSort() {
    final query = searchQuery.toLowerCase();
    final queryTokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    List<ActivityFeedItem> result = allFeedItems.where((item) {
      if (query.isEmpty) return true;

      final actor = item.actorName.toLowerCase();
      final actorCompact = actor.replaceAll(' ', '');
      final title = item.title.toLowerCase();
      final subtitle = item.subtitle.toLowerCase();
      final searchable = '$actor $title $subtitle';

      return queryTokens.every(
        (token) => searchable.contains(token) || actorCompact.contains(token),
      );
    }).toList();

    switch (sortOption) {
      case ActivitySortOption.newest:
        result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        break;
      case ActivitySortOption.oldest:
        result.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        break;
      case ActivitySortOption.nameAZ:
        result.sort((a, b) => a.actorName.compareTo(b.actorName));
        break;
      case ActivitySortOption.nameZA:
        result.sort((a, b) => b.actorName.compareTo(a.actorName));
        break;
    }

    feedItems = result;
  }

  String _formatDateLabel(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final input = DateTime(dt.year, dt.month, dt.day);

    if (input == today) return AppStrings.tr('today');
    if (input == today.subtract(const Duration(days: 1))) {
      return AppStrings.tr('yesterday');
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatFullDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTotalWorkTime(dynamic totalHours) {
    if (totalHours == null) return '--';
    if (totalHours is num) {
      if (totalHours == totalHours.roundToDouble()) {
        return '${totalHours.toInt()}h';
      }
      return '${totalHours.toStringAsFixed(1)}h';
    }

    final parsed = num.tryParse(totalHours.toString());
    if (parsed == null) return '--';
    if (parsed == parsed.roundToDouble()) {
      return '${parsed.toInt()}h';
    }
    return '${parsed.toStringAsFixed(1)}h';
  }

  String _trf(String key, Map<String, String> values) {
    var text = AppStrings.tr(key);
    values.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
    return text;
  }
}
