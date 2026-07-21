class ApiEndpoints {
  ApiEndpoints._();

  // AUTH
  static const String googleAuth = '/auth/google/callback';
  static const String refreshToken = '/auth/refresh-token';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  // workspace
  static const String myWorkspaces = '/workspace/me';
}
