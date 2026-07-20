import 'package:flutter/material.dart';

class ActivityFeedItem {
  final String actorName;
  final String title;
  final String subtitle;
  final String timeLabel;
  final String dateLabel;
  final String scanIn;
  final String scanOut;
  final String totalWorkTime;
  final DateTime occurredAt;
  final IconData icon;
  final Color color;

  const ActivityFeedItem({
    required this.actorName,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.dateLabel,
    required this.scanIn,
    required this.scanOut,
    required this.totalWorkTime,
    required this.occurredAt,
    required this.icon,
    required this.color,
  });
}
