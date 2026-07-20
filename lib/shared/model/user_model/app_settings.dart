class AppSettings {
  final bool notificationsEnabled;
  final bool biometricLock;

  AppSettings({
    required this.notificationsEnabled,
    required this.biometricLock,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled:
          json['notifications_enabled'] ??
          json['notification_enable'] ??
          json['notification_enabled'] ??
          true,
      biometricLock: json['biometric_lock'] ?? false,
    );
  }
}
