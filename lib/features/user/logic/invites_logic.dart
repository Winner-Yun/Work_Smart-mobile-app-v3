import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/repository/invite_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/invite_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/invites_screen.dart';
import 'package:flutter_worksmart_app/shared/model/invite_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paginated workspace-invite list with search filtering and accept/reject actions.
abstract class InvitesLogic extends State<InvitesScreen> {
  final InviteRepository _inviteRepo = InviteRepository(InviteService());
  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  List<Invite> invites = [];
  int _currentPage = 1;
  final int limit = 5;
  int _totalInvites = 0;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String searchQuery = '';
  final Set<String> actionLoadingIds = <String>{};
  bool _isReloadingOnScrollUp = false;

  // Invites aren't workspace-scoped, so one global key covers the cached first page.
  static const String _cacheKeyInvitesPage1 = 'cached_invites_page1';

  @override
  void initState() {
    super.initState();
    _initInvites();
    scrollController.addListener(_onScroll);
    searchController.addListener(() {
      if (mounted) {
        setState(() => searchQuery = searchController.text.trim());
      }
    });
  }

  /// Local-first init: show cached page-1 invites instantly, then refresh
  /// in the background; falls back to a blocking fetch on a cold start.
  Future<void> _initInvites() async {
    final List<Invite> cached = await _loadCachedInvites();

    if (!mounted) return;

    if (cached.isNotEmpty) {
      // Keep the loading state up briefly so an instant cache read doesn't pop in jarringly.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (!mounted) return;
      setState(() {
        invites = cached;
        _currentPage = 1;
        // Pagination stays disabled until the background refresh confirms the real total.
        _totalInvites = cached.length;
        hasMore = false;
        isLoading = false;
      });
      unawaited(fetchInvites(isRefresh: true, silent: true));
    } else {
      await fetchInvites(isRefresh: true);
    }
  }

  Future<List<Invite>> _loadCachedInvites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedJson = prefs.getString(_cacheKeyInvitesPage1);
      if (cachedJson == null) return <Invite>[];
      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded
          .map((json) => Invite.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[InvitesLogic] Error loading cached invites: $e');
      return <Invite>[];
    }
  }

  Future<void> _saveCachedInvites(List<Invite> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKeyInvitesPage1,
        jsonEncode(data.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[InvitesLogic] Error saving invites cache: $e');
    }
  }

  bool _hasInvitesChanged(List<Invite> newData) {
    final String newJson = jsonEncode(newData.map((e) => e.toJson()).toList());
    final String currentJson = jsonEncode(
      invites.map((e) => e.toJson()).toList(),
    );
    return newJson != currentJson;
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 60 &&
        !isLoadingMore &&
        !isLoading &&
        hasMore) {
      loadMoreInvites();
    }

    if (scrollController.position.pixels < -100 && !_isReloadingOnScrollUp) {
      _isReloadingOnScrollUp = true;
      fetchInvites(isRefresh: true);
    } else if (scrollController.position.pixels >= -10) {
      _isReloadingOnScrollUp = false;
    }
  }

  /// Fetches page 1 of invites. `isRefresh` resets to page 1; `silent` skips
  /// the blocking skeleton and only updates state if the page actually changed.
  Future<void> fetchInvites({bool isRefresh = false, bool silent = false}) async {
    if (isRefresh && !silent) {
      setState(() {
        isLoading = true;
        _currentPage = 1;
        hasMore = true;
      });
    }

    try {
      final response = await _inviteRepo.getMyInvites(page: 1, limit: limit);
      if (!mounted) return;

      if (silent) {
        final bool changed = _hasInvitesChanged(response.data);
        final bool newHasMore = response.data.length < response.total;
        if (changed || newHasMore != hasMore || response.total != _totalInvites) {
          setState(() {
            if (changed) invites = response.data;
            _totalInvites = response.total;
            _currentPage = 1;
            hasMore = newHasMore;
          });
        }
        if (changed) {
          await _saveCachedInvites(response.data);
        }
        return;
      }

      setState(() {
        invites = response.data;
        _totalInvites = response.total;
        _currentPage = 1;
        hasMore = invites.length < _totalInvites;
        isLoading = false;
      });
      await _saveCachedInvites(response.data);
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        debugPrint('[InvitesLogic] Background refresh failed: $e');
        return;
      }
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('invites_load_failed')}: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> loadMoreInvites() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    try {
      final int nextPage = _currentPage + 1;
      final response = await _inviteRepo.getMyInvites(
        page: nextPage,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        invites.addAll(response.data);
        _totalInvites = response.total;
        hasMore = invites.length < _totalInvites;
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingMore = false);
    }
  }

  Future<void> handleAcceptInvite(String inviteId) async {
    setState(() => actionLoadingIds.add(inviteId));
    try {
      final response = await _inviteRepo.acceptInvite(inviteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message.isNotEmpty
                ? response.message
                : AppStrings.tr('invite_accept_success'),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      await fetchInvites(isRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('invite_action_failed')}: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => actionLoadingIds.remove(inviteId));
    }
  }

  Future<void> handleRejectInvite(String inviteId) async {
    setState(() => actionLoadingIds.add(inviteId));
    try {
      final response = await _inviteRepo.rejectInvite(inviteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message.isNotEmpty
                ? response.message
                : AppStrings.tr('invite_reject_success'),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      await fetchInvites(isRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('invite_action_failed')}: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => actionLoadingIds.remove(inviteId));
    }
  }

  List<Invite> get filteredInvites {
    if (searchQuery.isEmpty) return invites;
    final String query = searchQuery.toLowerCase();
    return invites.where((invite) {
      return invite.position.toLowerCase().contains(query) ||
          invite.role.toLowerCase().contains(query) ||
          invite.email.toLowerCase().contains(query) ||
          invite.workspaceId.toLowerCase().contains(query) ||
          invite.status.toLowerCase().contains(query);
    }).toList();
  }
}
