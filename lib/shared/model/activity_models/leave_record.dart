class LeaveRecord {
  final String requestId;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final String? attachmentUrl;

  LeaveRecord({
    required this.requestId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.attachmentUrl,
  });

  // Calculate inclusive days 
  int get durationInDays => endDate.difference(startDate).inDays + 1;

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRecord(
      requestId: json['request_id'] ?? '',
      type: json['type'] ?? '',
      startDate: DateTime.parse(
        json['start_date'] ?? DateTime.now().toString(),
      ),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toString()),
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      attachmentUrl: json['attachment_url'],
    );
  }
}
