class AttendanceModel {
  final String id;
  final String workspaceId;
  final String uid;
  final String date;
  final String checkIn;
  final String checkOut;
  final double totalHours;
  final String status;
  final double? latitude;
  final double? longitude;
  final bool faceVerified;
  final bool livenessVerified;
  final bool mockLocationDetected;

  AttendanceModel({
    required this.id,
    required this.workspaceId,
    required this.uid,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.totalHours,
    required this.status,
    this.latitude,
    this.longitude,
    required this.faceVerified,
    required this.livenessVerified,
    required this.mockLocationDetected,
  });

  // The backend returns MongoDB extended JSON: object ids come as
  // `{"$oid": "..."}` and datetimes as `{"$date": "..."}` rather than plain
  // strings, so every field is unwrapped defensively instead of assuming a
  // single fixed shape.
  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final String? checkInRaw = _readTimeField(json, const [
      'check_in',
      'checkIn',
      'check_in_time',
      'checkInTime',
      'checked_in_at',
    ]);
    final String? checkOutRaw = _readTimeField(json, const [
      'check_out',
      'checkOut',
      'check_out_time',
      'checkOutTime',
      'checked_out_at',
    ]);

    final String checkIn = _formatTimeField(checkInRaw);
    final String checkOut = _formatTimeField(checkOutRaw);

    final String date =
        _readString(json, const ['date', 'work_date', 'attendance_date']) ??
        _dateKeyFromIso(checkInRaw) ??
        _dateKeyFromIso(_readTimeField(json, const ['created_at'])) ??
        _formatDateKey(DateTime.now());

    return AttendanceModel(
      id: _extractObjectId(json['id'] ?? json['_id']),
      workspaceId: _extractObjectId(
        json['workspace_id'] ?? json['workspaceId'],
      ),
      uid: _extractObjectId(json['user_id'] ?? json['uid'] ?? json['userId']),
      date: date,
      checkIn: checkIn,
      checkOut: checkOut,
      totalHours:
          _readDouble(json, const ['total_hours', 'totalHours']) ??
          _calculateWorkingHours(checkIn, checkOut) ??
          0.0,
      status: (json['status'] ?? 'absent').toString(),
      latitude: _readDouble(json, const ['latitude', 'lat']),
      longitude: _readDouble(json, const ['longitude', 'lng']),
      faceVerified:
          _readBool(json, const ['face_verified', 'faceVerified']) ?? false,
      livenessVerified:
          _readBool(json, const ['liveness_verified', 'livenessVerified']) ??
          false,
      mockLocationDetected:
          _readBool(json, const [
            'mock_location_detected',
            'mockLocationDetected',
          ]) ??
          false,
    );
  }

  /// Legacy `{uid, date, check_in, check_out, total_hours, status}` shape
  /// consumed by the existing homepage/calendar/stats UI code.
  Map<String, dynamic> toLegacyMap() => {
    'uid': uid,
    'date': date,
    'check_in': checkIn,
    'check_out': checkOut,
    'total_hours': totalHours,
    'status': status,
  };

  // Full round-trip shape (accepted back by fromJson) used for local
  // caching — toLegacyMap() above deliberately drops fields the UI doesn't
  // need, which would lose data if used to re-hydrate a cached list.
  Map<String, dynamic> toJson() => {
    'id': id,
    'workspace_id': workspaceId,
    'user_id': uid,
    'date': date,
    'check_in': checkIn,
    'check_out': checkOut,
    'total_hours': totalHours,
    'status': status,
    'latitude': latitude,
    'longitude': longitude,
    'face_verified': faceVerified,
    'liveness_verified': livenessVerified,
    'mock_location_detected': mockLocationDetected,
  };

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
  /// already-plain ISO or 12-hour string.
  static String? _readTimeField(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is Map) {
        final dynamic inner = value[r'$date'];
        final String text = (inner ?? '').toString().trim();
        if (text.isNotEmpty) return text;
        continue;
      }
      final String text = value.toString().trim();
      if (text.isNotEmpty) return text;
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

  static double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool? _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value != null) {
        final normalized = value.toString().trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return null;
  }

  static String _formatTimeField(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--:--';

    if (RegExp(
      r'^\d{1,2}:\d{2}\s*(AM|PM)$',
      caseSensitive: false,
    ).hasMatch(raw.trim())) {
      return raw.trim().toUpperCase();
    }

    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return '--:--';
    final DateTime local = parsed.toLocal();
    final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  static String? _dateKeyFromIso(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return _formatDateKey(parsed.toLocal());
  }

  static String _formatDateKey(DateTime dateTime) {
    return '${dateTime.year}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  static double? _calculateWorkingHours(String checkIn, String checkOut) {
    final DateTime? inTime = _parse12hTime(checkIn);
    final DateTime? outTime = _parse12hTime(checkOut);
    if (inTime == null || outTime == null) return null;

    Duration diff = outTime.difference(inTime);
    if (diff.isNegative) diff = const Duration();
    return double.parse((diff.inMinutes / 60).toStringAsFixed(1));
  }

  static DateTime? _parse12hTime(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty || normalized == '--:--') return null;

    final List<String> parts = normalized.split(RegExp(r'\s+'));
    if (parts.length != 2) return null;

    final List<String> hm = parts[0].split(':');
    if (hm.length != 2) return null;

    int? hour = int.tryParse(hm[0]);
    final int? minute = int.tryParse(hm[1]);
    if (hour == null || minute == null) return null;

    final String period = parts[1].toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
