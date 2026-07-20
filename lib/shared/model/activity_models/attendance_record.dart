import 'lat_lng.dart';

class AttendanceRecord {
  final String uid;
  final String date;
  final String checkIn;
  final String checkOut;
  final double totalHours;
  final String status;
  final LatLng location;

  AttendanceRecord({
    required this.uid,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.totalHours,
    required this.status,
    required this.location,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      uid: json['uid'] ?? '',
      date: json['date'] ?? '',
      checkIn: json['check_in'] ?? '--:--',
      checkOut: json['check_out'] ?? '--:--',
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'absent',
      location: LatLng.fromJson(json['lat_lng'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'date': date,
    'check_in': checkIn,
    'check_out': checkOut,
    'total_hours': totalHours,
    'status': status,
    'lat_lng': location.toJson(),
  };
}
