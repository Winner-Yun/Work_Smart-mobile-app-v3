class LeaveModel {
  final String id;
  final String workspaceId;
  final String uid;
  final String leaveType;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? attachmentUrl;

  LeaveModel({
    required this.id,
    required this.workspaceId,
    required this.uid,
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.attachmentUrl,
  });

  int get durationInDays => endDate.difference(startDate).inDays + 1;

  // The backend returns MongoDB extended JSON: object ids come as
  // `{"$oid": "..."}` and datetimes as `{"$date": "..."}` rather than plain
  // strings, so every field is unwrapped defensively instead of assuming a
  // single fixed shape.
  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id: _extractObjectId(json['id'] ?? json['_id']),
      workspaceId: _extractObjectId(
        json['workspace_id'] ?? json['workspaceId'],
      ),
      uid: _extractObjectId(json['user_id'] ?? json['uid'] ?? json['userId']),
      leaveType: _readString(json, const ['leave_type', 'leaveType']) ?? '',
      reason: _readString(json, const ['reason']) ?? '',
      startDate:
          _readDate(json, const ['start_date', 'startDate']) ??
          DateTime.now(),
      endDate:
          _readDate(json, const ['end_date', 'endDate']) ?? DateTime.now(),
      status: _readString(json, const ['status']) ?? 'pending',
      attachmentUrl: _readString(json, const [
        'attachment_url',
        'attachmentUrl',
        'attachment',
      ]),
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  /// Reads a datetime-ish field, unwrapping MongoDB extended JSON
  /// (`{"$date": "..."}`) if present; otherwise treats the value as an
  /// already-plain ISO string.
  static DateTime? _readDate(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is Map) {
        final dynamic inner = value[r'$date'];
        final DateTime? parsed = DateTime.tryParse((inner ?? '').toString());
        if (parsed != null) return parsed;
        continue;
      }
      final DateTime? parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Unwraps a MongoDB extended-JSON object id (`{"$oid": "..."}`), or
  /// returns the value as-is if it's already a plain string.
  static String _extractObjectId(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return (value[r'$oid'] ?? '').toString();
    }
    return value.toString();
  }
}
