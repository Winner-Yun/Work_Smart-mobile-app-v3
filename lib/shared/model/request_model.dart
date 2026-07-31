class RequestModel {
  final String id;
  final String workspaceId;
  final String userId;
  final String title;
  final String description;
  final List<String> attachments;
  final String status;
  final String? response;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RequestModel({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.title,
    required this.description,
    required this.attachments,
    required this.status,
    this.response,
    required this.createdAt,
    this.updatedAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      workspaceId: (json['workspace_id'] ?? json['workspaceId'] ?? '')
          .toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      attachments: _readStringList(json['attachments']),
      status: (json['status'] ?? 'pending').toString(),
      response: json['response']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? json['createdAt'] ?? '')
                  .toString()) ??
              DateTime.now(),
      updatedAt: DateTime.tryParse(
        (json['updated_at'] ?? json['updatedAt'] ?? '').toString(),
      ),
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
