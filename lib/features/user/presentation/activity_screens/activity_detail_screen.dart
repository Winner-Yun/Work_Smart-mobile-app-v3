import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/activity_feed_item.dart';

class ActivityDetailScreen extends StatelessWidget {
  final ActivityFeedItem item;

  const ActivityDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('live_activity_title'))),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300 && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: item.color.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: item.color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.subtitle,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.color,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                              .animate()
                              .fadeIn(duration: 280.ms)
                              .slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 16),
                          Divider(
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.2),
                          ),
                          const SizedBox(height: 12),
                          _detailRow(
                            context,
                            AppStrings.tr('check_in_title'),
                            item.scanIn,
                          ).animate().fadeIn(delay: 80.ms, duration: 220.ms),
                          const SizedBox(height: 10),
                          _detailRow(
                            context,
                            AppStrings.tr('check_out_title'),
                            item.scanOut,
                          ).animate().fadeIn(delay: 140.ms, duration: 220.ms),
                          const SizedBox(height: 10),
                          _detailRow(
                            context,
                            AppStrings.tr('total_hours'),
                            item.totalWorkTime,
                          ).animate().fadeIn(delay: 200.ms, duration: 220.ms),
                          const SizedBox(height: 10),
                          _detailRow(
                            context,
                            AppStrings.tr('date_label'),
                            item.dateLabel,
                          ).animate().fadeIn(delay: 260.ms, duration: 220.ms),
                          const SizedBox(height: 34),
                          Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppStrings.tr(
                                          'activity_swipe_back_hint',
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 340.ms, duration: 220.ms)
                              .slideY(begin: 0.05, end: 0),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 240.ms)
                    .scale(
                      begin: const Offset(0.98, 0.98),
                      end: const Offset(1, 1),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
