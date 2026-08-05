import 'dart:io';

import 'package:flutter_worksmart_app/features/user/service/leave_service.dart';
import 'package:flutter_worksmart_app/shared/model/leave_model.dart';

class LeaveRepository {
  final LeaveService _service;

  LeaveRepository(this._service);

  Future<LeaveModel> createLeave(
    String workspaceId, {
    required String leaveType,
    required String reason,
    required String startDate,
    String? endDate,
    File? attachment,
  }) async {
    final json = await _service.createLeave(
      workspaceId,
      leaveType: leaveType,
      reason: reason,
      startDate: startDate,
      endDate: endDate,
      attachment: attachment,
    );
    return LeaveModel.fromJson(json);
  }

  Future<LeaveModel> updateLeave(
    String leaveId, {
    String? leaveType,
    String? reason,
    String? startDate,
    String? endDate,
    File? attachment,
  }) async {
    final json = await _service.updateLeave(
      leaveId,
      leaveType: leaveType,
      reason: reason,
      startDate: startDate,
      endDate: endDate,
      attachment: attachment,
    );
    return LeaveModel.fromJson(json);
  }

  Future<void> deleteLeave(String leaveId) {
    return _service.deleteLeave(leaveId);
  }

  /// The current user's leave requests for [workspaceId]. Tolerates a plain
  /// list or a paginated wrapper under `data`/`records`/`leaves`/`items`/`results`.
  Future<List<LeaveModel>> getMyLeaves(
    String workspaceId, {
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? dateFilter,
  }) async {
    final dynamic raw = await _service.fetchMyLeaves(
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
          raw['leaves'] ??
          raw['leave_requests'] ??
          raw['items'] ??
          raw['results'];
      if (nested is List) {
        rawList = nested;
      }
    }

    if (rawList != null) {
      return rawList
          .whereType<Map>()
          .map((json) => LeaveModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }

    if (raw is Map<String, dynamic> && raw.isNotEmpty) {
      return [LeaveModel.fromJson(raw)];
    }

    return <LeaveModel>[];
  }
}
