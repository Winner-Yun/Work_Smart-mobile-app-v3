import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/request_detail_screen.dart';
import 'package:flutter_worksmart_app/features/user/repository/request_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/request_service.dart';
import 'package:flutter_worksmart_app/shared/model/request_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/request_skeleton_loading.dart';
import 'package:flutter_worksmart_app/shared/widget/common/sliver_pinned_header_delegate.dart';
import 'package:flutter_worksmart_app/shared/widget/common/task_icon_button.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const RequestScreen({super.key, this.loginData});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final RequestRepository _requestRepo = RequestRepository(RequestService());
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  List<RequestModel> _requests = <RequestModel>[];
  String? _workspaceId;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _scrolledUp = false;

  // Set by tapping a stat in the header; null shows every request.
  String? _statusFilter;

  // Manual/post-create refresh only — the silent background refresh never touches this flag.
  bool get isRefreshing => _isRefreshing;

  List<RequestModel> get _visibleRequests => _statusFilter == null
      ? _requests
      : _requests
            .where((r) => r.status.toLowerCase() == _statusFilter)
            .toList();

  SharedPreferences? _prefs;
  late final ScrollController _scrollController;

  String? get _cacheKey => (_workspaceId == null || _workspaceId!.isEmpty)
      ? null
      : 'cached_requests_$_workspaceId';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  // Matches the homepage/leave-screen overscroll-to-refresh gesture.
  void _onScroll() {
    if (_scrollController.position.pixels < -100 &&
        !_scrolledUp &&
        !_isRefreshing) {
      _scrolledUp = true;
      _loadRequests();
    } else if (_scrollController.position.pixels >= -10) {
      _scrolledUp = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Cache-first: show cached data immediately, refresh in the background; only a cold start shows the skeleton.
  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    _workspaceId = _prefs!.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final bool hasLocalData = await _loadFromLocal();

    if (!mounted) return;

    if (hasLocalData) {
      // Brief artificial delay so loading doesn't pop in instantly.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fetchFromNetwork(showLoading: false);
    } else {
      await _fetchFromNetwork(showLoading: true);
    }
  }

  Future<bool> _loadFromLocal() async {
    final prefs = _prefs;
    final cacheKey = _cacheKey;
    if (prefs == null || cacheKey == null) return false;

    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson == null) return false;

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      _requests =
          decoded
              .map(
                (json) => RequestModel.fromJson(json as Map<String, dynamic>),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _requests.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Only toggles _isLoading — _isRefreshing is owned by `_loadRequests`.
  Future<void> _fetchFromNetwork({required bool showLoading}) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) return;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final requests = await _requestRepo.getMyRequests(workspaceId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;

      final newJson = jsonEncode(requests.map((r) => r.toJson()).toList());
      final currentJson = jsonEncode(_requests.map((r) => r.toJson()).toList());

      if (newJson != currentJson) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
        await _saveToCache(newJson);
      } else if (showLoading) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveToCache(String requestsJson) async {
    final prefs = _prefs;
    final cacheKey = _cacheKey;
    if (prefs == null || cacheKey == null) return;
    try {
      await prefs.setString(cacheKey, requestsJson);
    } catch (_) {}
  }

  // Swaps to the skeleton instead of the overscroll indicator; clears `_isRefreshing`
  // in finally so a failed refresh can't permanently block further pulls.
  Future<void> _loadRequests() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await _fetchFromNetwork(showLoading: false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openCreateSheet() async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) return;

    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _CreateRequestSheet(
          workspaceId: workspaceId,
          requestRepo: _requestRepo,
        );
      },
    );

    if (created == true) _loadRequests();
  }

  Future<void> _openRequestDetail(RequestModel request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailScreen(request: request),
      ),
    );
  }

  // Only a pending request can still be withdrawn — once it's been seen or
  // actioned on, deleting it would erase the admin's response.
  Future<void> _handleDeleteTap(RequestModel request) async {
    final bool deleted = await _confirmDeleteRequest(request);
    if (deleted) _removeRequestLocally(request);
  }

  Future<bool> _confirmDeleteRequest(RequestModel request) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          size: 40,
        ),
        title: Text(
          AppStrings.tr('delete_request_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppStrings.tr('delete_request_confirm_desc'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppStrings.tr('cancel_button')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppStrings.tr('delete_button'),
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _requestRepo.deleteRequest(request.id);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              '${AppStrings.tr('request_delete_failed')}: ${e.toString().replaceFirst('Exception: ', '')}',
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
        );
      }
      return false;
    }
  }

  void _removeRequestLocally(RequestModel request) {
    setState(() {
      _requests.removeWhere((r) => r.id == request.id);
    });
    unawaited(
      _saveToCache(jsonEncode(_requests.map((r) => r.toJson()).toList())),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return Colors.purple;
      case 'seen':
        return AppColors.info;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'in_progress':
        return Icons.autorenew_rounded;
      case 'seen':
        return Icons.visibility_outlined;
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return AppStrings.tr('request_status_in_progress');
      case 'completed':
        return AppStrings.tr('request_status_completed');
      case 'seen':
        return AppStrings.tr('request_status_seen');
      case 'pending':
      default:
        return AppStrings.tr('request_status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RequestModel> visibleRequests = _visibleRequests;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          AppStrings.tr('request_menu'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TaskIconButton(loginData: widget.loginData, iconColor: Colors.white),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
        child: const Icon(Icons.add, color: AppColors.textLight),
      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
      body: _isLoading || _isRefreshing
          ? const RequestSkeletonLoading()
          : Stack(
              alignment: Alignment.topCenter,
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: SliverPinnedHeaderDelegate(
                        height: 76,
                        child: Container(
                          width: double.infinity,
                          color: Theme.of(context).scaffoldBackgroundColor,

                          child: _buildStatsHeader(),
                        ),
                      ),
                    ),
                    if (visibleRequests.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: DataEmptyState(
                            imageAsset: AppImg.emptyState,
                            message: AppStrings.tr('no_requests_yet'),
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _buildRequestItem(visibleRequests[index])
                                .animate()
                                .fadeIn(
                                  delay: (60 * index).ms,
                                  duration: 240.ms,
                                )
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  curve: Curves.easeOut,
                                );
                          }, childCount: visibleRequests.length),
                        ),
                      ),
                  ],
                ),
                _buildPullToRefreshIndicator(),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    final int pendingCount = _requests
        .where((r) => r.status.toLowerCase() == 'pending')
        .length;
    final int seenCount = _requests
        .where((r) => r.status.toLowerCase() == 'seen')
        .length;
    final int inProgressCount = _requests
        .where((r) => r.status.toLowerCase() == 'in_progress')
        .length;
    final int completedCount = _requests
        .where((r) => r.status.toLowerCase() == 'completed')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              AppColors.warning,
              pendingCount,
              AppStrings.tr('request_status_pending'),
              'pending',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatTile(
              AppColors.info,
              seenCount,
              AppStrings.tr('request_status_seen'),
              'seen',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatTile(
              Colors.purple,
              inProgressCount,
              AppStrings.tr('request_status_in_progress'),
              'in_progress',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatTile(
              AppColors.success,
              completedCount,
              AppStrings.tr('request_status_completed'),
              'completed',
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStatTile(Color color, int count, String label, String status) {
    final bool isSelected = _statusFilter == status;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => _statusFilter = isSelected ? null : status);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 3,
              width: isSelected ? 22 : 0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).dividerColor.withOpacity(0.15),
    );
  }

  // Matches the homepage/leave-screen overscroll-to-refresh gesture.
  Widget _buildPullToRefreshIndicator() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        if (!_scrollController.hasClients) return const SizedBox.shrink();

        double overscroll = _scrollController.position.pixels < 0
            ? -_scrollController.position.pixels
            : 0.0;

        if (overscroll <= 0 || _isLoading || _isRefreshing) {
          return const SizedBox.shrink();
        }

        double progress = (overscroll / 100.0).clamp(0.0, 1.0);
        bool isReadyToRelease = progress >= 0.95;

        return Positioned(
          top: 10 + (overscroll * 0.2),
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
                angle: progress * 6.28,
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

  Widget _buildRequestItem(RequestModel request) {
    final statusColor = _statusColor(request.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRequestDetail(request),
        onLongPress: request.status.toLowerCase() == 'pending'
            ? () => _handleDeleteTap(request)
            : null,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: statusColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      request.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon(request.status),
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(request.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if ((request.response ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: statusColor, width: 3),
                    ),
                  ),
                  child: Text(
                    request.response!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _dateFormatter.format(request.createdAt),
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (request.status.toLowerCase() == 'pending')
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _handleDeleteTap(request),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRequestSheet extends StatefulWidget {
  final String workspaceId;
  final RequestRepository requestRepo;

  const _CreateRequestSheet({
    required this.workspaceId,
    required this.requestRepo,
  });

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _pickedImages = [];
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    if (_pickedImages.length >= 5) return;
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _pickedImages.add(file));
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.requestRepo.createRequest(
        widget.workspaceId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: _pickedImages.map((f) => File(f.path)).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            '${AppStrings.tr('request_submit_failed')}: ${e.toString().replaceFirst('Exception: ', '')}',
            style: const TextStyle(color: AppColors.textLight),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).scaffoldBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      alignLabelWithHint: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.tr('new_request_title'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: _fieldDecoration(
                  context,
                  AppStrings.tr('title_label'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? AppStrings.tr('title_required')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _fieldDecoration(
                  context,
                  AppStrings.tr('description_label'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? AppStrings.tr('description_required')
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.tr('attachments_optional_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int i = 0; i < _pickedImages.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_pickedImages[i].path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () => _removeImage(i),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.textLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cancel,
                                size: 20,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().scale(duration: 180.ms),
                  if (_pickedImages.length < 5)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textLight,
                            ),
                          ),
                        )
                      : Text(
                          AppStrings.tr('submit_request_button'),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
