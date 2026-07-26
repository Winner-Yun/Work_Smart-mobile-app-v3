import 'package:flutter_worksmart_app/features/user/service/attendance_service.dart';
import 'package:flutter_worksmart_app/shared/model/attendance_model.dart';

class AttendanceRepository {
  final AttendanceService _service;

  AttendanceRepository(this._service);

  Future<AttendanceModel> checkIn(
    String workspaceId, {
    required double latitude,
    required double longitude,
    required bool faceVerified,
    required bool livenessVerified,
    required bool mockLocationDetected,
  }) async {
    final json = await _service.checkIn(
      workspaceId,
      latitude: latitude,
      longitude: longitude,
      faceVerified: faceVerified,
      livenessVerified: livenessVerified,
      mockLocationDetected: mockLocationDetected,
    );
    return AttendanceModel.fromJson(json);
  }

  Future<AttendanceModel> checkOut(
    String workspaceId, {
    required double latitude,
    required double longitude,
    required bool faceVerified,
    required bool livenessVerified,
    required bool mockLocationDetected,
  }) async {
    final json = await _service.checkOut(
      workspaceId,
      latitude: latitude,
      longitude: longitude,
      faceVerified: faceVerified,
      livenessVerified: livenessVerified,
      mockLocationDetected: mockLocationDetected,
    );
    return AttendanceModel.fromJson(json);
  }

  /// The current user's attendance records for [workspaceId]. Tolerates the
  /// backend returning either a single record or a paginated list under a
  /// wrapper key (`data`/`records`/`attendance`/`items`/`results`).
  Future<List<AttendanceModel>> getMyAttendance(
    String workspaceId, {
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? dateFilter,
  }) async {
    final dynamic raw = await _service.fetchMyAttendance(
      workspaceId,
      page: page,
      limit: limit,
      sortBy: sortBy,
      sortOrder: sortOrder,
      status: status,
      dateFilter: dateFilter,
    );

    List<dynamic>? rawList;
    if (raw is List) {
      rawList = raw;
    } else if (raw is Map<String, dynamic>) {
      final dynamic nested =
          raw['data'] ??
          raw['records'] ??
          raw['attendance'] ??
          raw['attendances'] ??
          raw['items'] ??
          raw['results'];
      if (nested is List) {
        rawList = nested;
      }
    }

    if (rawList != null) {
      return rawList
          .whereType<Map>()
          .map(
            (json) => AttendanceModel.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    }

    if (raw is Map<String, dynamic> && raw.isNotEmpty) {
      return [AttendanceModel.fromJson(raw)];
    }

    return <AttendanceModel>[];
  }

  /// A single record representing "today" for the current user, merging
  /// multiple rows for the same day (in case the backend logs check-in and
  /// check-out as separate entries rather than one row with both times).
  Future<AttendanceModel?> getTodayAttendance(String workspaceId) async {
    final records = await getMyAttendance(
      workspaceId,
      dateFilter: 'today',
      sortBy: 'check_in',
      sortOrder: 'asc',
      limit: 50,
    );

    if (records.isEmpty) return null;
    if (records.length == 1) return records.first;

    String checkIn = '--:--';
    String checkOut = '--:--';
    double totalHours = 0;
    String status = records.first.status;

    for (final record in records) {
      if (checkIn == '--:--' && record.checkIn != '--:--') {
        checkIn = record.checkIn;
      }
      if (record.checkOut != '--:--') {
        checkOut = record.checkOut;
      }
      if (record.totalHours > totalHours) {
        totalHours = record.totalHours;
      }
      if (record.status.isNotEmpty && record.status != 'absent') {
        status = record.status;
      }
    }

    final AttendanceModel latest = records.last;
    return AttendanceModel(
      id: latest.id,
      workspaceId: latest.workspaceId,
      uid: latest.uid,
      date: latest.date,
      checkIn: checkIn,
      checkOut: checkOut,
      totalHours: totalHours,
      status: status,
      latitude: latest.latitude,
      longitude: latest.longitude,
      faceVerified: latest.faceVerified,
      livenessVerified: latest.livenessVerified,
      mockLocationDetected: latest.mockLocationDetected,
    );
  }
}
