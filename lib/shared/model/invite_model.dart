class Invite {
  final String id;
  final String workspaceId;
  final String email;
  final String position;
  final String role;
  final String status;
  final String createdAt;
  final String expiresAt;

  Invite({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.position,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspace_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspace_id': workspaceId,
    'email': email,
    'position': position,
    'role': role,
    'status': status,
    'created_at': createdAt,
    'expires_at': expiresAt,
  };
}

class InviteResponse {
  final int page;
  final int limit;
  final int total;
  final List<Invite> data;

  InviteResponse({
    required this.page,
    required this.limit,
    required this.total,
    required this.data,
  });

  factory InviteResponse.fromJson(Map<String, dynamic> json) {
    return InviteResponse(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => Invite.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
