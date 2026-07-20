class TelegramConfig {
  final String botUsername;
  final String botLink;
  final String qrCodeData;

  TelegramConfig({
    required this.botUsername,
    required this.botLink,
    required this.qrCodeData,
  });

  factory TelegramConfig.fromJson(Map<String, dynamic> json) {
    return TelegramConfig(
      botUsername: json['bot_username'] ?? '',
      botLink: json['bot_link'] ?? '',
      qrCodeData: json['qr_code_data'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'bot_username': botUsername,
    'bot_link': botLink,
    'qr_code_data': qrCodeData,
  };
}
