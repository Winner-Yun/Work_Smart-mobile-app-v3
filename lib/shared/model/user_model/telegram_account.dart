class TelegramAccount {
  final bool isConnected;
  final String telegramId;
  final String telegramUsername;

  TelegramAccount({
    required this.isConnected,
    required this.telegramId,
    required this.telegramUsername,
  });

  factory TelegramAccount.fromJson(Map<String, dynamic> json) {
    return TelegramAccount(
      isConnected: json['is_connected'] ?? false,
      telegramId: json['telegram_id'] ?? '',
      telegramUsername: json['telegram_username'] ?? '',
    );
  }
}
