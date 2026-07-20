class Badge {
  final String id;
  final String key;
  final bool isUnlocked;

  Badge({required this.id, required this.key, required this.isUnlocked});

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] ?? '',
      key: json['key'] ?? '',
      isUnlocked: json['is_unlocked'] ?? false,
    );
  }
}
