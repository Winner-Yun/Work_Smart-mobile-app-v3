class GeofenceModel {
  final String id;
  final String workspaceId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String status;
  final DateTime createdAt;

  GeofenceModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.status,
    required this.createdAt,
  });

  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    // Helper to extract string from either flat id or nested {'$oid': '...'}
    String parseObjectId(dynamic value) {
      if (value is Map) return value[r'$oid']?.toString() ?? '';
      return value?.toString() ?? '';
    }

    // Helper to extract date from either flat string or nested {'$date': '...'}
    DateTime parseDate(dynamic value) {
      if (value is Map) {
        return DateTime.tryParse(value[r'$date']?.toString() ?? '') ??
            DateTime.now();
      }
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return GeofenceModel(
      id: json['id'] != null
          ? json['id'].toString()
          : parseObjectId(json['_id']),
      workspaceId: parseObjectId(json['workspace_id']),
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      radiusMeters: json['radius_meters'] ?? 0,
      status: json['status'] ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}
