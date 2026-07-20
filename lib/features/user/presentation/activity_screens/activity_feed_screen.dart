import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/logic/activity_feed_logic.dart';
import 'package:flutter_worksmart_app/features/user/presentation/activity_screens/activity_detail_screen.dart';
import 'package:flutter_worksmart_app/shared/widget/common/activity_feed_skeleton_loading.dart';

PreferredSizeWidget buildActivityAppBar(
  BuildContext context, {
  required bool showTelegramConnectAction,
  required VoidCallback onTelegramConfigTap,
  required VoidCallback onNotificationTap,
  required Widget notificationBell,
}) {
  return AppBar(
    scrolledUnderElevation: 0,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    elevation: 0,
    centerTitle: false,
    title: Text(
      AppStrings.tr('live_activity_title'),
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w800,
        fontSize: 22,
      ),
    ),
    actions: [
      // if (showTelegramConnectAction)
      //   IconButton(
      //     onPressed: onTelegramConfigTap,
      //     icon: Icon(
      //       Icons.send_rounded,
      //       color: Theme.of(context).iconTheme.color,
      //     ),
      //   ),
      IconButton(onPressed: onNotificationTap, icon: notificationBell),
    ],
  );
}

class ActivityFeedScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const ActivityFeedScreen({super.key, this.loginData});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ActivityFeedLogic {
  final Set<String> _animatedItemKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const ActivityFeedSkeletonLoading();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: AppStrings.tr('search_name_or_activity'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ActivitySortOption>(
                onSelected: onSortChanged,
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    color: Theme.of(context).iconTheme.color,
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ActivitySortOption.newest,
                    child: Text(AppStrings.tr('sort_newest_first')),
                  ),
                  PopupMenuItem(
                    value: ActivitySortOption.oldest,
                    child: Text(AppStrings.tr('sort_oldest_first')),
                  ),
                  PopupMenuItem(
                    value: ActivitySortOption.nameAZ,
                    child: Text(AppStrings.tr('sort_name_az')),
                  ),
                  PopupMenuItem(
                    value: ActivitySortOption.nameZA,
                    child: Text(AppStrings.tr('sort_name_za')),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.04, end: 0),
        Expanded(
          child: feedItems.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.tr('no_records'),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: refreshFeed,
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    itemCount: feedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = feedItems[index];
                      final itemKey =
                          '${item.actorName}|${item.title}|${item.timeLabel}|${item.occurredAt.toIso8601String()}';
                      final shouldAnimate = _animatedItemKeys.add(itemKey);

                      final listItem = InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActivityDetailScreen(item: item),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: item.color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: item.color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.timeLabel,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (!shouldAnimate) {
                        return listItem;
                      }

                      return listItem
                          .animate()
                          .fadeIn(delay: (index * 40).ms, duration: 220.ms)
                          .slideX(begin: 0.06, end: 0);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
