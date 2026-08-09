part of '../homepage_logic.dart';

mixin _AttendanceScanMixin on _HomePageLogicState {
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

  void _syncScanStateFromAttendanceData() {
    final bool checkInDone = _isTypeCompleted('check_in');
    final bool checkOutDone = _isTypeCompleted('check_out');

    // Policies with no check-out step complete attendance at check-in —
    // never advance to the check_out scan type.
    if (!requiresCheckOut) {
      _stopCheckOutCooldown();
      selectedAttendanceScanType = 'check_in';
      if (checkInDone) {
        hasMockScanSuccess = true;
        lastMockScanType = 'check_in';
        lastMockScanAt = _getCompletedTypeTime('check_in');
      } else {
        hasMockScanSuccess = false;
        lastMockScanAt = null;
      }
      _syncDeadlineRefreshWatcher();
      return;
    }

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

  void selectAttendanceScanType(String type) {
    if (type != 'check_in' && type != 'check_out') return;
    if (type == 'check_out' && !requiresCheckOut) return;

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
    if (!requiresCheckOut) {
      if (_isTypeCompleted('check_in')) {
        return false;
      }
    } else {
      if (selectedAttendanceScanType != 'check_out') {
        return false;
      }
      if (!_isTypeCompleted('check_in') || _isTypeCompleted('check_out')) {
        return false;
      }
    }

    final DateTime? deadlineAt = _getCheckOutScanDeadlineTime();
    if (deadlineAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(deadlineAt);
  }

  bool get isAttendanceScanBlockedByDeadline {
    final String completionType = requiresCheckOut ? 'check_out' : 'check_in';
    if (_isTypeCompleted(completionType)) {
      return false;
    }

    final DateTime? deadlineAt = _getCheckOutScanDeadlineTime();
    if (deadlineAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(deadlineAt);
  }

  // Blocks the scan card on weekends/public holidays per the workspace's
  // holiday config, and on any date explicitly listed in workspaceHolidays.
  bool get isTodayHoliday {
    final now = DateTime.now();
    final HolidayConfigModel? config = currentHolidayConfig;

    if (config != null) {
      switch (config.includeWeekend) {
        case 'Sunday only':
          if (now.weekday == DateTime.sunday) return true;
          break;
        case 'Saturday and Sunday':
          if (now.weekday == DateTime.saturday ||
              now.weekday == DateTime.sunday) {
            return true;
          }
          break;
        default:
          break;
      }
    }

    if (config == null || config.includePublicHolidays) {
      if (workspaceHolidays.any((holiday) => holiday.isSameDate(now))) {
        return true;
      }
    }

    return false;
  }

  String? get todayHolidayName {
    final now = DateTime.now();
    for (final holiday in workspaceHolidays) {
      if (holiday.isSameDate(now)) return holiday.name;
    }
    return null;
  }

  String get todayHolidayLabel =>
      todayHolidayName ?? AppStrings.tr('holiday_today_label');

  bool get isBeforeCheckInWindow {
    if (selectedAttendanceScanType != 'check_in') return false;
    if (_isTypeCompleted('check_in')) return false;

    final DateTime? windowStart = _parse12hTime(officeCheckInTime);
    if (windowStart == null) return false;

    return DateTime.now().isBefore(windowStart);
  }

  String get checkInWindowStartLabel {
    final DateTime? windowStart = _parse12hTime(officeCheckInTime);
    if (windowStart == null) return '--:--';
    return _formatDateTimeTo12Hour(windowStart);
  }

  bool get isAttendanceScanDisabled =>
      isAttendanceScanBlockedByDeadline || isBeforeCheckInWindow;

  bool get shouldShowCheckOutDeadlineCard =>
      !hasMockScanSuccess && isCheckOutScanDeadlineReached;

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

  String get selectedAttendanceActionText => isTodayHoliday
      ? todayHolidayLabel
      : isScanCooldownActive
      ? '${AppStrings.tr('wait')} ${_formatCooldownDuration(checkOutCooldownSeconds)}'
      : isBeforeCheckInWindow
      ? '${AppStrings.tr('check_in')} ${AppStrings.tr('opens_at')} $checkInWindowStartLabel'
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

  // "Check-in only" policies have no check-out time, so the deadline falls back
  // to the check-in window's own deadline.
  DateTime? _getCheckOutScanDeadlineTime() {
    final DateTime? windowStart = _parse12hTime(
      requiresCheckOut ? officeCheckOutTime : officeCheckInTime,
    );
    if (windowStart == null || deadlineScanMinutes <= 0) {
      return null;
    }

    return windowStart.add(Duration(minutes: deadlineScanMinutes));
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
            requiresCheckOut &&
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
