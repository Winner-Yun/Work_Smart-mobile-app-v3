class HolidayConfigModel {
  final String workspaceId;
  final bool includePublicHolidays;
  final String includeWeekend;
  final DateTime updatedAt;

  HolidayConfigModel({
    required this.workspaceId,
    required this.includePublicHolidays,
    required this.includeWeekend,
    required this.updatedAt,
  });

  factory HolidayConfigModel.fromJson(Map<String, dynamic> json) {
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

    return HolidayConfigModel(
      workspaceId: parseObjectId(json['workspace_id']),
      includePublicHolidays: json['include_public_holidays'] ?? false,
      includeWeekend: (json['include_weekend'] ?? 'None').toString(),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}
