class TaskModel {
  final String id;
  final String workspaceId;
  final String createdBy;
  final String title;
  final String? description;
  final String visibility;
  final List<String> assignedTo;
  final String? deadline;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.workspaceId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.visibility,
    required this.assignedTo,
    this.deadline,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      workspaceId: (json['workspace_id'] ?? json['workspaceId'] ?? '')
          .toString(),
      createdBy: (json['created_by'] ?? json['createdBy'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      visibility: (json['visibility'] ?? 'public').toString(),
      assignedTo: _readStringList(json['assigned_to'] ?? json['assignedTo']),
      deadline: json['deadline']?.toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'pending').toString(),
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspace_id': workspaceId,
    'created_by': createdBy,
    'title': title,
    'description': description,
    'visibility': visibility,
    'assigned_to': assignedTo,
    'deadline': deadline,
    'priority': priority,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
