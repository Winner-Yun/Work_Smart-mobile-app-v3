class Goal {
  final String title;
  final String desc;
  final double progressPercent;
  final String daysCount;

  Goal({
    required this.title,
    required this.desc,
    required this.progressPercent,
    required this.daysCount,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      title: json['title'] ?? '',
      desc: json['desc'] ?? '',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      daysCount: json['days_count'] ?? '',
    );
  }
}
