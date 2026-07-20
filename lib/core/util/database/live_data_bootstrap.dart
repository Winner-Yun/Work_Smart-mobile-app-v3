import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/core/util/database/attendance_data.dart';
import 'package:flutter_worksmart_app/core/util/database/office_data.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';

class LiveDataBootstrap {
  static final RealtimeDataController _controller = RealtimeDataController();

  static bool _initialized = false;
  static StreamSubscription<List<Map<String, dynamic>>>? _usersSubscription;
  static StreamSubscription<Map<String, dynamic>?>? _officeSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>?
  _attendanceSubscription;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final users = await _controller.fetchUserRecords();
      setUsersFinalData(users);
    } catch (e, stack) {
      debugPrint('❌ Error loading user records: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      final office = await _controller.fetchOfficeConnection();
      if (office != null) {
        setOfficeMasterData(office);
      }
    } catch (e, stack) {
      debugPrint('❌ Error loading office connection: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      final records = await _controller.fetchAttendanceRecords();
      setAttendanceRecords(records);
    } catch (e, stack) {
      debugPrint('❌ Error loading attendance records: $e');
      debugPrintStack(stackTrace: stack);
    }

    _usersSubscription = _controller.watchUserRecords().listen(
      setUsersFinalData,
      onError: (e, stack) {
        debugPrint('❌ Error watching user records: $e');
        debugPrintStack(stackTrace: stack ?? StackTrace.current);
      },
    );

    _officeSubscription = _controller.watchOfficeConnection().listen(
      (office) {
        if (office == null) return;
        setOfficeMasterData(office);
      },
      onError: (e, stack) {
        debugPrint('❌ Error watching office connection: $e');
        debugPrintStack(stackTrace: stack ?? StackTrace.current);
      },
    );

    _attendanceSubscription = _controller.watchAttendanceRecords().listen(
      setAttendanceRecords,
      onError: (e, stack) {
        debugPrint('❌ Error watching attendance records: $e');
        debugPrintStack(stackTrace: stack ?? StackTrace.current);
      },
    );
  }

  static Future<void> dispose() async {
    await _usersSubscription?.cancel();
    await _officeSubscription?.cancel();
    await _attendanceSubscription?.cancel();
    _usersSubscription = null;
    _officeSubscription = null;
    _attendanceSubscription = null;
    _initialized = false;
  }
}
