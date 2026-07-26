import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/features/user/repository/invite_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/invite_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/invites_screen.dart';
import 'package:flutter_worksmart_app/shared/model/invite_model.dart';

/// Paginated workspace-invite list with search filtering and accept/reject
/// actions. Adapted from the old Firestore-notifications screen's invite
/// tab, now driven entirely by the REST `InviteRepository`.
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

  @override
  void initState() {
    super.initState();
    fetchInvites(isRefresh: true);
    scrollController.addListener(_onScroll);
    searchController.addListener(() {
      if (mounted) {
        setState(() => searchQuery = searchController.text.trim());
      }
    });
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

  Future<void> fetchInvites({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        isLoading = true;
        _currentPage = 1;
        hasMore = true;
      });
    }

    try {
      final response = await _inviteRepo.getMyInvites(page: 1, limit: limit);
      if (!mounted) return;
      setState(() {
        invites = response.data;
        _totalInvites = response.total;
        _currentPage = 1;
        hasMore = invites.length < _totalInvites;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
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
                : 'Invite accepted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await fetchInvites(isRefresh: true);
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
                : 'Invite rejected.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      await fetchInvites(isRefresh: true);
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
