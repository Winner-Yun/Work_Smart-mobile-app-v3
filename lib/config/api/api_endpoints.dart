class ApiEndpoints {
  ApiEndpoints._();

  // AUTH
  static const String googleAuth = '/auth/google/callback';
  static const String refreshToken = '/auth/refresh-token';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String updateProfileImage = '/auth/me/profile-image';

  // workspace
  static const String myWorkspaces = '/workspace/me';
  static String workspaceGeofence(String workspaceId) =>
      '/workspace/$workspaceId/geofence';
  static String workspacePolicy(String workspaceId) =>
      '/workspace/$workspaceId/policy';

  // My INVITE
  static const String myInvites = '/invite/me';

  // INVITE ACTIONS
  static String acceptInvite(String inviteId) => '/invite/$inviteId/accept';
  static String rejectInvite(String inviteId) => '/invite/$inviteId/reject';
  static String joinInviteByCode(String code) => '/invite/join/$code';

  // FACE
  static const String faceRegister = '/face/register';
  static const String faceMe = '/face/me';

  // ATTENDANCE
  static String attendanceCheckIn(String workspaceId) =>
      '/attendance/$workspaceId/attendance/check-in';
  static String attendanceCheckOut(String workspaceId) =>
      '/attendance/$workspaceId/attendance/check-out';
  static String attendanceMe(String workspaceId) =>
      '/attendance/$workspaceId/me';

  // LEAVE
  static String createLeave(String workspaceId) => '/leave/$workspaceId/leave';
  static String leaveById(String leaveId) => '/leave/$leaveId';
  static String myLeaves(String workspaceId) => '/leave/$workspaceId/me';

  // TASKS
  static String workspaceTasks(String workspaceId) =>
      '/workspace/$workspaceId/tasks';
  static String taskById(String taskId) => '/workspace/task/$taskId';
  static String taskStatus(String taskId) => '/workspace/task/$taskId/status';

  // REQUESTS
  static String workspaceRequests(String workspaceId) =>
      '/request/$workspaceId';
  static String myRequests(String workspaceId) => '/request/$workspaceId/me';
  static String requestStatus(String requestId) => '/request/$requestId/status';
  static String requestById(String requestId) => '/request/$requestId';

  // CONFIG
  static const String configData = '/config/data';
}
