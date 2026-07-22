class Workspace {
  final String id;
  final String workspaceName;
  final String description;
  final String status;
  final int memberCount; // Added for later, defaults to 1 for now
  final String? createdAt;
  final String? updatedAt;

  Workspace({
    required this.id,
    required this.workspaceName,
    required this.description,
    required this.status,
    required this.memberCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id']?.toString() ?? '',
      workspaceName: json['workspace_name']?.toString() ?? 'Unknown Workspace',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'inactive',
      memberCount:
          json['member_count'] ?? 1, // <--- Defaulting to 1 as requested
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_name': workspaceName,
        'description': description,
        'status': status,
        'member_count': memberCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
