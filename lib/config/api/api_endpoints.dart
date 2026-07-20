/// Endpoint paths only — the domain lives in `ApiConfig.baseUrl`.
class ApiEndpoints {
  ApiEndpoints._();

  // ─────────── AUTH ───────────

  /// Exchanges a Google ID token for backend access and refresh tokens.
  static const String googleAuth = '/auth/google/callback';

  /// Exchanges an expired access token for a new one.
  static const String refreshToken = '/auth/refresh-token';

  /// Returns the currently authenticated user (used to validate a cached
  /// session on app start / auto-login).
  static const String me = '/auth/me';

  /// Invalidates the current session on the backend.
  static const String logout = '/auth/logout';
}
