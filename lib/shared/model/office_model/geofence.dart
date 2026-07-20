class Geofence {
  final double lat;
  final double lng;
  final int radiusMeters;
  final String addressLabel;

  Geofence({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.addressLabel,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> center = json['center'] is Map
        ? Map<String, dynamic>.from(json['center'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> legacyLatLng = json['lat_lng'] is Map
        ? Map<String, dynamic>.from(json['lat_lng'] as Map)
        : json['latLng'] is Map
        ? Map<String, dynamic>.from(json['latLng'] as Map)
        : json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : const <String, dynamic>{};

    final double lat = (center['lat'] as num?)?.toDouble() ??
        (center['latitude'] as num?)?.toDouble() ??
        (legacyLatLng['lat'] as num?)?.toDouble() ??
        (legacyLatLng['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble() ??
        (json['latitude'] as num?)?.toDouble() ??
        0.0;
    final double lng = (center['lng'] as num?)?.toDouble() ??
        (center['longitude'] as num?)?.toDouble() ??
        (legacyLatLng['lng'] as num?)?.toDouble() ??
        (legacyLatLng['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble() ??
        (json['longitude'] as num?)?.toDouble() ??
        0.0;

    return Geofence(
      lat: lat,
      lng: lng,
      radiusMeters:
          (json['radius_meters'] as num?)?.toInt() ??
          (json['radiusMeters'] as num?)?.toInt() ??
          (json['radius'] as num?)?.toInt() ??
          0,
      addressLabel: json['address_label'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'center': {'lat': lat, 'lng': lng},
    'radius_meters': radiusMeters,
    'address_label': addressLabel,
  };
}
