class PolicyModel {
  final String id;
  final String workspaceId;
  final String name;
  final String workStartTime;
  final String workEndTime;
  final String checkInStart;
  final String checkOutStart;
  final int lateBufferMinutes;
  final int deadlineScanMinutes;
  final int annualLeaveLimit;
  final int sickLeaveLimit;
  final String status;
  final DateTime createdAt;

  PolicyModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.workStartTime,
    required this.workEndTime,
    required this.checkInStart,
    required this.checkOutStart,
    required this.lateBufferMinutes,
    required this.deadlineScanMinutes,
    required this.annualLeaveLimit,
    required this.sickLeaveLimit,
    required this.status,
    required this.createdAt,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    String parseObjectId(dynamic value) {
      if (value is Map) return value[r'$oid']?.toString() ?? '';
      return value?.toString() ?? '';
    }

    DateTime parseDate(dynamic value) {
      if (value is Map) {
        return DateTime.tryParse(value[r'$date']?.toString() ?? '') ??
            DateTime.now();
      }
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return PolicyModel(
      id: json['id'] != null
          ? json['id'].toString()
          : parseObjectId(json['_id']),
      workspaceId: parseObjectId(json['workspace_id']),
      name: json['name'] ?? '',
      workStartTime: json['work_start_time'] ?? '',
      workEndTime: json['work_end_time'] ?? '',
      checkInStart: json['check_in_start'] ?? '',
      checkOutStart: json['check_out_start'] ?? '',
      lateBufferMinutes: json['late_buffer_minutes'] ?? 0,
      deadlineScanMinutes: json['deadline_scan_minutes'] ?? 0,
      annualLeaveLimit: json['annual_leave_limit'] ?? 0,
      sickLeaveLimit: json['sick_leave_limit'] ?? 0,
      status: json['status'] ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}
