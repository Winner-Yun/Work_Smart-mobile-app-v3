class ApiEndpoints {
  ApiEndpoints._();

  // AUTH
  static const String googleAuth = '/auth/google/callback';
  static const String refreshToken = '/auth/refresh-token';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  // workspace
  static const String myWorkspaces = '/workspace/me';
  static String workspaceGeofence(String workspaceId) =>
      '/workspace/$workspaceId/geofence';
  static String workspacePolicy(String workspaceId) =>
      '/workspace/$workspaceId/policy';

  // INVITE
  static const String myInvites = '/invite/me';

  // INVITE ACTIONS
  static String acceptInvite(String inviteId) => '/invite/$inviteId/accept';
  static String rejectInvite(String inviteId) => '/invite/$inviteId/reject';
}
