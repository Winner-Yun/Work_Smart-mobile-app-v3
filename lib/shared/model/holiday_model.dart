class HolidayModel {
  final String id;
  final String workspaceId;
  final String name;
  final String date;
  final DateTime? parsedDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HolidayModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.date,
    required this.parsedDate,
    required this.createdAt,
    this.updatedAt,
  });

  bool isSameDate(DateTime other) {
    final DateTime? d = parsedDate;
    if (d == null) return false;
    return d.year == other.year && d.month == other.month && d.day == other.day;
  }

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
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

    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is Map) {
        return DateTime.tryParse(value[r'$date']?.toString() ?? '');
      }
      return DateTime.tryParse(value.toString());
    }

    final String dateStr = json['date'] is Map
        ? (json['date'][r'$date']?.toString() ?? '')
        : (json['date']?.toString() ?? '');

    return HolidayModel(
      id: json['id'] != null
          ? json['id'].toString()
          : parseObjectId(json['_id']),
      workspaceId: parseObjectId(json['workspace_id']),
      name: (json['name'] ?? '').toString(),
      date: dateStr,
      parsedDate: parseOptionalDate(json['date']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseOptionalDate(json['updated_at']),
    );
  }
}
