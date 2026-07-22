/// Notification Screens - Handles user notifications and workspace invites.
///
/// This file contains two main components:
/// 1. [NotificationScreen] - Main screen with tabs for general notifications and invites
/// 2. [_InviteNotificationsTab] - Tab handling workspace invite management with pagination
///
/// Features:
/// - Real-time notification streaming via Firebase Realtime Database
/// - Swipe actions for mark as read/unread and delete
/// - Invite accept/reject with pagination and search
/// - Custom scroll-up pull-to-refresh animation matching WorkspaceScreen
/// - Animated list items and skeleton loading states
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/invite_service.dart';
import 'package:flutter_worksmart_app/shared/model/invite_model.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:intl/intl.dart';

/// Main notification screen displaying user notifications and workspace invites.
///
/// Uses a [DefaultTabController] with 2 tabs:
/// - Notifications: Real-time stream from Firebase
/// - Invites: Paginated workspace invitations
class NotificationScreen extends StatefulWidget {
  /// Login data containing user uid and other session info
  final Map<String, dynamic>? loginData;

  const NotificationScreen({super.key, this.loginData});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  /// Controller for Firebase Realtime Database operations
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();

  /// Extracts and trims the user ID from login data
  String get _uid => (widget.loginData?['uid'] ?? '').toString().trim();

  /// Deletes a notification by ID and shows confirmation snackbar
  Future<void> _deleteNotification(String notificationId) async {
    if (_uid.isEmpty) return;

    await _realtimeDataController.deleteUserNotification(_uid, notificationId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: Text(AppStrings.tr('notif_deleted')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Marks a single notification as read in Firebase
  Future<void> _markAsRead(String notificationId) async {
    if (_uid.isEmpty) return;
    await _realtimeDataController.markUserNotificationRead(
      _uid,
      notificationId,
      isRead: true,
    );
  }

  /// Marks a single notification as unread in Firebase
  Future<void> _markAsUnread(String notificationId) async {
    if (_uid.isEmpty) return;
    await _realtimeDataController.markUserNotificationRead(
      _uid,
      notificationId,
      isRead: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle case where user ID is missing - show empty state
    if (_uid.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: _buildEmptyState(message: 'User not found.'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: TabBarView(
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _realtimeDataController.watchUserNotifications(_uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (notifications.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildNotificationList(notifications);
              },
            ),
            _InviteNotificationsTab(loginData: widget.loginData),
          ],
        ),
      ),
    );
  }

  /// Builds the app bar with back button, title, mark-all-read action, and tab bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: Theme.of(context).iconTheme.color,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        AppStrings.tr('notifications_title'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.done_all,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: AppStrings.tr('read_all'),
          onPressed: () async {
            if (_uid.isEmpty) return;
            await _realtimeDataController.markAllUserNotificationsRead(_uid);
          },
        ),
      ],
      bottom: TabBar(
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: AppColors.textGrey,
        indicatorColor: Theme.of(context).colorScheme.primary,
        tabs: const [
          Tab(
            icon: Icon(Icons.notifications_none_rounded, size: 20),
            text: 'Notifications',
          ),
          Tab(
            icon: Icon(Icons.mail_outline_rounded, size: 20),
            text: 'Invites',
          ),
        ],
      ),
    );
  }

  /// Builds scrollable list of notifications with swipe actions (read/unread, delete)
  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final item = notifications[index];
        final String notificationId = (item['id'] ?? '').toString();
        final bool isRead = (item['isRead'] as bool?) ?? false;
        final IconData toggleIcon = isRead
            ? Icons.mark_email_unread_outlined
            : Icons.done_all;
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Slidable(
            key: ValueKey<String>('notif-$notificationId'),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.46,
              children: [
                const SizedBox(width: 5),
                CustomSlidableAction(
                  onPressed: (_) => isRead
                      ? _markAsUnread(notificationId)
                      : _markAsRead(notificationId),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  flex: 1,
                  child: Center(
                    child: Icon(toggleIcon, color: Colors.white, size: 25),
                  ),
                ),
                const SizedBox(width: 5),
                CustomSlidableAction(
                  onPressed: (_) => _deleteNotification(notificationId),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                  flex: 1,
                  child: const Center(
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ],
            ),
            child: GestureDetector(
              onDoubleTap: () => _handleNotificationTap(item),
              child: _buildNotificationItem(item, index),
            ),
          ),
        );
      },
    );
  }

  /// Builds a single notification card with icon, title, message, timestamp and unread indicator
  Widget _buildNotificationItem(Map<String, dynamic> data, int index) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.width < 360;

    final bool isRead = (data['isRead'] as bool?) ?? false;
    final String title = (data['title'] ?? '').toString();
    final String message = (data['message'] ?? '').toString();
    final String type = (data['type'] ?? 'general').toString();
    final String status = _resolveLeaveNotificationStatus(data);
    final DateTime? timestamp = _readTimestamp(data['timestamp']);

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 15),
      decoration: BoxDecoration(
        color: isRead
            ? Theme.of(context).cardTheme.color?.withValues(alpha: 0.6)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isRead
              ? Theme.of(context).dividerColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(type, status),
          SizedBox(width: size.width * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmall ? 13 : 14,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: isSmall ? 10 : 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.006),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                    fontSize: isSmall ? 12 : 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              margin: EdgeInsets.only(left: size.width * 0.02, top: 5),
              width: isSmall ? 6 : 8,
              height: isSmall ? 6 : 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
  }

  /// Returns appropriate icon and color based on notification type and status
  /// - leave: green check for approved, red cancel for rejected
  /// - attendance: orange registration icon
  /// - default: primary color campaign icon
  Widget _buildIcon(String type, String status) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'leave':
        if (status == 'rejected') {
          iconData = Icons.cancel_outlined;
          iconColor = Colors.red;
        } else {
          iconData = Icons.check_circle_outline;
          iconColor = Colors.green;
        }
        break;
      case 'attendance':
        iconData = Icons.how_to_reg_rounded;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.campaign_outlined;
        iconColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  /// Resolves leave notification status from explicit field or by parsing title/message
  /// Checks for 'rejected' or 'approved' keywords if status field is empty
  String _resolveLeaveNotificationStatus(Map<String, dynamic> data) {
    final String explicitStatus = (data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (explicitStatus.isNotEmpty) {
      return explicitStatus;
    }

    final String title = (data['title'] ?? '').toString().trim().toLowerCase();
    final String message = (data['message'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String combined = '$title $message';

    if (combined.contains('rejected')) {
      return 'rejected';
    }
    if (combined.contains('approved')) {
      return 'approved';
    }
    return '';
  }

  /// Safely extracts DateTime from raw timestamp value
  DateTime? _readTimestamp(dynamic raw) {
    if (raw is DateTime) return raw;
    return null;
  }

  /// Formats timestamp to readable string (e.g., 'Jan 5, 2:30 PM')
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }
    return DateFormat('MMM d, h:mm a').format(timestamp);
  }

  /// Handles tap on notification:
  /// - Marks as read
  /// - Navigates based on type: attendance -> main app (index 3), leave -> leave detail, else dialog
  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final String notificationId = (notification['id'] ?? '').toString();
    final String type = (notification['type'] ?? 'general')
        .toString()
        .trim()
        .toLowerCase();

    await _markAsRead(notificationId);
    if (!mounted) return;

    if (type == 'attendance') {
      final args = Map<String, dynamic>.from(widget.loginData ?? {});
      args['initialIndex'] = 3;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.appmain,
        (route) => false,
        arguments: args,
      );
      return;
    }

    if (type == 'leave') {
      Navigator.of(
        context,
      ).pushNamed(AppRoute.leaveDatailScreen, arguments: widget.loginData);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text((notification['title'] ?? '').toString()),
          content: Text((notification['message'] ?? '').toString()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Builds empty state widget with image and message when no notifications exist
  Widget _buildEmptyState({String? message}) {
    return DataEmptyState(
      imageAsset: AppImg.emptyState,
      iconColor: Colors.grey[300],
      spacing: 15,
      message: message ?? AppStrings.tr('no_notif'),
      textStyle: const TextStyle(color: AppColors.textGrey),
    );
  }
}

/// Tab widget for displaying and managing workspace invites
///
/// Features:
/// - Paginated fetching (5 items per page)
/// - Infinite scroll loading
/// - Custom pull-to-refresh indicator and scroll-up refresh matching WorkspaceScreen
/// - Search filtering by position, role, email, workspaceId, status
/// - Accept/Reject actions with loading states
class _InviteNotificationsTab extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const _InviteNotificationsTab({this.loginData});

  @override
  State<_InviteNotificationsTab> createState() =>
      _InviteNotificationsTabState();
}

class _InviteNotificationsTabState extends State<_InviteNotificationsTab> {
  /// Service for invite API calls
  final InviteService _inviteService = InviteService();

  /// Controller for infinite scroll detection
  final ScrollController _scrollController = ScrollController();

  /// Controller for search input field
  final TextEditingController _searchController = TextEditingController();

  List<Invite> _invites = []; // Current list of loaded invites
  int _currentPage = 1; // Current pagination page
  final int _limit = 5; // Items per page
  int _totalInvites = 0; // Total count from server
  bool _isLoading = false; // Initial loading state
  bool _isLoadingMore = false; // Pagination loading state
  bool _hasMore = true; // Whether more pages exist
  String _searchQuery = ''; // Current search filter text
  final Set<String> _actionLoadingIds =
      {}; // IDs of invites being accepted/rejected
  bool _isReloadingOnScrollUp =
      false; // Prevents duplicate reload on overscroll

  @override
  void initState() {
    super.initState();
    _fetchInvites(isRefresh: true); // Load first page on init
    _scrollController.addListener(
      _onScroll,
    ); // Listen for infinite scroll & pull-to-refresh
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Handles scroll events for infinite scroll and custom pull-to-refresh matching WorkspaceScreen
  void _onScroll() {
    // Infinite scroll trigger near bottom
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 60 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMoreInvites();
    }

    // Pull-to-refresh overscroll trigger at -100px (matches WorkspaceScreen)
    if (_scrollController.position.pixels < -100 && !_isReloadingOnScrollUp) {
      _isReloadingOnScrollUp = true;
      _fetchInvites(isRefresh: true);
    } else if (_scrollController.position.pixels >= -10) {
      _isReloadingOnScrollUp = false;
    }
  }

  /// Fetches invites from API - resets to page 1 if isRefresh is true
  Future<void> _fetchInvites({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    try {
      final response = await _inviteService.fetchMyInvites(
        page: 1,
        limit: _limit,
      );

      if (!mounted) return;

      setState(() {
        _invites = response.data;
        _totalInvites = response.total;
        _currentPage = 1;
        _hasMore = _invites.length < _totalInvites;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error fetching invites: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Loads next page of invites for infinite scroll
  Future<void> _loadMoreInvites() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await _inviteService.fetchMyInvites(
        page: nextPage,
        limit: _limit,
      );

      if (!mounted) return;

      setState(() {
        _currentPage = nextPage;
        _invites.addAll(response.data);
        _totalInvites = response.total;
        _hasMore = _invites.length < _totalInvites;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Accepts a workspace invite and refreshes the list
  Future<void> _handleAcceptInvite(String inviteId) async {
    setState(() {
      _actionLoadingIds.add(inviteId);
    });

    try {
      final response = await _inviteService.acceptInvite(inviteId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message.isNotEmpty
                ? response.message
                : 'Invite accepted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _fetchInvites(isRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to accept invite: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoadingIds.remove(inviteId);
        });
      }
    }
  }

  /// Rejects a workspace invite and refreshes the list
  Future<void> _handleRejectInvite(String inviteId) async {
    setState(() {
      _actionLoadingIds.add(inviteId);
    });

    try {
      final response = await _inviteService.rejectInvite(inviteId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message.isNotEmpty ? response.message : 'Invite rejected.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      _fetchInvites(isRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to reject invite: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoadingIds.remove(inviteId);
        });
      }
    }
  }

  /// Returns filtered invites based on search query (position, role, email, workspaceId, status)
  List<Invite> get _filteredInvites {
    if (_searchQuery.isEmpty) return _invites;
    final query = _searchQuery.toLowerCase();
    return _invites.where((invite) {
      return invite.position.toLowerCase().contains(query) ||
          invite.role.toLowerCase().contains(query) ||
          invite.email.toLowerCase().contains(query) ||
          invite.workspaceId.toLowerCase().contains(query) ||
          invite.status.toLowerCase().contains(query);
    }).toList();
  }

  /// Custom Visual Indicator for pull-to-refresh matching WorkspaceScreen implementation
  Widget _buildPullToRefreshIndicator() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        if (!_scrollController.hasClients) return const SizedBox.shrink();

        // Get how far the user has pulled down past the top
        double overscroll = _scrollController.position.pixels < 0
            ? -_scrollController.position.pixels
            : 0.0;

        // Hide if not pulling or actively loading
        if (overscroll <= 0 || _isLoading) {
          return const SizedBox.shrink();
        }

        // Calculate progress to the -100 threshold
        double progress = (overscroll / 100.0).clamp(0.0, 1.0);
        bool isReadyToRelease = progress >= 0.95; // Almost at threshold

        return Positioned(
          top: 10 + (overscroll * 0.2), // Moves down slightly as user pulls
          child: Opacity(
            opacity: progress,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).cardTheme.color ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.white),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: progress * 6.28, // Rotates fully based on pull distance
                child: Icon(
                  isReadyToRelease
                      ? Icons.refresh_rounded
                      : Icons.arrow_downward_rounded,
                  color: isReadyToRelease
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade500,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInvites; // Apply search filter

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search invites...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor:
                  Theme.of(context).cardTheme.color ??
                  Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              _isLoading
                  ? _buildSkeletonList()
                  : filtered.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: DataEmptyState(
                          imageAsset: AppImg.emptyState,
                          iconColor: Colors.grey[300],
                          spacing: 15,
                          message: _searchQuery.isNotEmpty
                              ? 'No invites matching "$_searchQuery"'
                              : AppStrings.tr('no_notif'),
                          textStyle: const TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final invite = filtered[index];
                        return _buildInviteCard(invite, index);
                      },
                    ),
              _buildPullToRefreshIndicator(), // Overlay animated pull-to-refresh icon
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a list of animated skeleton placeholders while invites are loading
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: 4,
      itemBuilder: (context, index) {
        return _buildInviteSkeleton(index);
      },
    );
  }

  /// Single skeleton card item mirroring the dimensions of `_buildInviteCard`
  /// Uses shimmer-like fade animation to indicate loading
  Widget _buildInviteSkeleton(int index) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circle Icon Skeleton
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Badge row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 130,
                              height: 14,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 18,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Role text skeleton
                        Container(
                          width: 90,
                          height: 12,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Email text skeleton
                        Container(
                          width: 150,
                          height: 11,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              // Action Buttons Skeleton
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 0.4, end: 1.0, duration: 800.ms);
  }

  /// Builds a single invite card with position, role, email, status badge and accept/reject actions
  Widget _buildInviteCard(Invite invite, int index) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.width < 360;
    final bool isProcessing = _actionLoadingIds.contains(invite.id);
    final String status = invite.status.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(isSmall ? 12 : 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: size.width * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            invite.position.isNotEmpty
                                ? invite.position
                                : 'Workspace Invite',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmall ? 14 : 15,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    if (invite.role.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${invite.role}',
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    if (invite.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        invite.email,
                        style: TextStyle(
                          fontSize: isSmall ? 11 : 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (status == 'pending' || status.isEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _handleRejectInvite(invite.id),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _handleAcceptInvite(invite.id),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
  }

  /// Builds colored status badge (accepted=green, rejected=red, expired=grey, pending=orange)
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.isNotEmpty ? status.toUpperCase() : 'PENDING';

    switch (status) {
      case 'accepted':
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green;
        break;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red;
        break;
      case 'expired':
        bg = Colors.grey.withValues(alpha: 0.1);
        fg = Colors.grey;
        break;
      default:
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
