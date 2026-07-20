import 'badge.dart';
import 'goal.dart';

class Achievements {
  final int totalMedals;
  final int performanceScore;
  final int rankTrend;
  final Goal goal;
  final List<Badge> badges;

  Achievements({
    required this.totalMedals,
    required this.performanceScore,
    required this.rankTrend,
    required this.goal,
    required this.badges,
  });

  factory Achievements.fromJson(Map<String, dynamic> json) {
    return Achievements(
      totalMedals: json['total_medals'] ?? 0,
      performanceScore: json['performance_score'] ?? 0,
      rankTrend: json['rank_trend'] ?? 0,
      goal: Goal.fromJson(json['goal'] ?? {}),
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((e) => Badge.fromJson(e))
              .toList() ??
          [],
    );
  }
}
