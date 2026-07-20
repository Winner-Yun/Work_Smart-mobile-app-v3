final List<Map<String, dynamic>> attendanceRecords = <Map<String, dynamic>>[];

void setAttendanceRecords(List<Map<String, dynamic>> records) {
  attendanceRecords
    ..clear()
    ..addAll(records.map((item) => Map<String, dynamic>.from(item)));
}
