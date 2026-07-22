import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/features/user/logic/workspace_screen_logic.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';

class WorkspaceScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final ValueChanged<String> onWorkspaceConfirmed;
  final VoidCallback? onProfileTap;

  const WorkspaceScreen({
    super.key,
    this.loginData,
    required this.onWorkspaceConfirmed,
    this.onProfileTap,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends WorkspaceScreenLogic {
  String get _userName {
    if (currentUser != null && currentUser!.name.trim().isNotEmpty) {
      return currentUser!.name;
    }
    final data = widget.loginData;
    if (data != null) {
      final nested = data['user'] is Map ? data['user'] as Map : null;
      final name = (nested?['name'] ?? data['name'] ?? data['username'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) return name;
    }
    return 'User';
  }

  String? get _avatarUrl {
    if (currentUser != null && currentUser!.avatar.trim().isNotEmpty) {
      return currentUser!.avatar;
    }
    final data = widget.loginData;
    if (data != null) {
      final nested = data['user'] is Map ? data['user'] as Map : null;
      final avatar = (nested?['avatar'] ?? data['avatar'] ?? '')
          .toString()
          .trim();
      if (avatar.isNotEmpty) return avatar;
    }
    return null;
  }

  String _searchQuery = '';
  late final ScrollController _scrollController;
  bool _scrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Triggers refresh when over-scrolling past -100 pixels (pulling down)
    if (_scrollController.position.pixels < -100 && !_scrolledUp) {
      _scrolledUp = true;
      onRefresh();
    } else if (_scrollController.position.pixels >= -10) {
      _scrolledUp = false;
    }
  }

  bool get scrolledUp => _scrolledUp;

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<Workspace> get _filteredWorkspaces {
    if (_searchQuery.trim().isEmpty) return workspaces;
    return workspaces
        .where(
          (w) => w.workspaceName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildSearchBar(), // Always displayed
                    const SizedBox(height: 16),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          _buildBody(),
                          _buildPullToRefreshIndicator(), // Custom visual indicator
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(), // Always displayed
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);

    final bool showSkeleton =
        (isLoading || isRefreshing) &&
        currentUser == null &&
        _avatarUrl == null &&
        _userName == 'User' &&
        (widget.loginData == null || widget.loginData!.isEmpty);

    if (showSkeleton) {
      return AppBar(
        elevation: 0,
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _buildSkeletonBox(width: 42, height: 42, isCircle: true),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 50, height: 10),
                const SizedBox(height: 6),
                _buildSkeletonBox(width: 90, height: 14),
              ],
            ),
          ],
        ),
      );
    }

    final String displayName = _userName;
    final String? avatar = _avatarUrl;
    final String initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';

    return AppBar(
      elevation: 0,
      toolbarHeight: 80,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                onBackgroundImageError: avatar != null && avatar.isNotEmpty
                    ? (_, __) {}
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: theme.iconTheme.color,
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoute.notificationScreen,
                  arguments: widget.loginData,
                );
              },
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Workspace',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isLoading || isRefreshing ? '-' : '${workspaces.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Choose an active workspace to access your dashboard.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        enabled: !isLoading && !isRefreshing,
        decoration: InputDecoration(
          hintText: 'Search workspace...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: Colors.grey.shade500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // --- NEW: Custom Visual Indicator ---
  Widget _buildPullToRefreshIndicator() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        if (!_scrollController.hasClients) return const SizedBox.shrink();

        // Get how far the user has pulled down past the top
        double overscroll = _scrollController.position.pixels < 0
            ? -_scrollController.position.pixels
            : 0.0;

        // Hide it if we aren't pulling, or if it's already loading
        if (overscroll <= 0 || isLoading || isRefreshing) {
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

  Widget _buildBody() {
    if (isLoading || isRefreshing) return _buildSkeletonLoader();

    if (errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (workspaces.isEmpty || _filteredWorkspaces.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.80,
      ),
      itemCount: _filteredWorkspaces.length,
      itemBuilder: (context, index) {
        final workspace = _filteredWorkspaces[index];
        final isSelected = selectedWorkspaceId == workspace.id;
        return _buildWorkspaceGridCard(workspace, isSelected)
            .animate()
            .fade(duration: 250.ms, delay: (index * 40).ms)
            .scaleXY(begin: 0.95, end: 1.0);
      },
    );
  }

  Widget _buildWorkspaceGridCard(Workspace workspace, bool isSelected) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onWorkspaceSelected(workspace.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.15 : 0.04)
              : (Theme.of(context).cardTheme.color ??
                    (isDark ? Colors.grey.shade900 : Colors.white)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.2),
                        primaryColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      workspace.workspaceName.isNotEmpty
                          ? workspace.workspaceName[0].toUpperCase()
                          : 'W',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade400,
                      width: 1.8,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const Spacer(),
            Text(
              workspace.workspaceName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              workspace.description.isNotEmpty
                  ? workspace.description
                  : 'No details provided',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _userName.split(' ').first,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 13,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${workspace.memberCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double radius = 8,
    bool isCircle = false,
  }) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade300,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.3, end: 0.8, duration: 700.ms);
  }

  Widget _buildSkeletonLoader() {
    return GridView.builder(
      controller:
          _scrollController, // Added to allow scroll-to-refresh even when loading
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.80,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBox(width: 40, height: 40, radius: 12),
              const Spacer(),
              _buildSkeletonBox(width: 90, height: 14),
              const SizedBox(height: 6),
              _buildSkeletonBox(width: 110, height: 10),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSkeletonBox(width: 45, height: 12),
                  _buildSkeletonBox(width: 35, height: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.workspaces_outline,
                size: 48,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No Matching Workspaces'
                  : 'No Workspaces Available',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Try searching with a different keyword.'
                    : 'You aren\'t assigned to any workspace yet.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onProfileTap != null) widget.onProfileTap!();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Setup Profile'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = selectedWorkspaceId != null;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          // Disabled while loading/refreshing or if no workspace is selected
          onPressed: hasSelection && !isLoading && !isRefreshing
              ? onConfirmSelection
              : null,
          style: ElevatedButton.styleFrom(
            elevation: hasSelection ? 2 : 0,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade300,
            disabledForegroundColor: isDark
                ? Colors.grey.shade500
                : Colors.grey.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Enter Workspace',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
