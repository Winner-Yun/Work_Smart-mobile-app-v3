import 'package:flutter/material.dart';

class TutorialData {
  static final List<Map<String, dynamic>> pages = [
    {
      'icon': Icons.dashboard_customize_outlined,
      'title': 'admin_tutorial_title_1',
      'subtitle': 'admin_tutorial_subtitle_1',
      'color': const Color(0xFF2563EB), // Web Blue
    },
    {
      'icon': Icons.supervised_user_circle_outlined,
      'title': 'admin_tutorial_title_2',
      'subtitle': 'admin_tutorial_subtitle_2',
      'color': const Color(0xFF059669), // Emerald Green
    },
    {
      'icon': Icons.bar_chart_rounded,
      'title': 'admin_tutorial_title_3',
      'subtitle': 'admin_tutorial_subtitle_3',
      'color': const Color(0xFFEA580C), // Orange
    },
    {
      'icon': Icons.settings_applications_outlined,
      'title': 'admin_tutorial_title_4',
      'subtitle': 'admin_tutorial_subtitle_4',
      'color': const Color(0xFF7C3AED), // Violet
    },
  ];
}
