import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/repository/leave_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/policy_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/leave_service.dart';
import 'package:flutter_worksmart_app/features/user/service/policy_service.dart';
import 'package:flutter_worksmart_app/shared/model/leave_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/system_loading_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SickLeaveRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const SickLeaveRequestScreen({super.key, this.loginData});

  @override
  State<SickLeaveRequestScreen> createState() => _SickLeaveRequestScreenState();
}

class _SickLeaveRequestScreenState extends State<SickLeaveRequestScreen> {
  // Fallback total used until the workspace policy (cached locally, or
  // freshly fetched from the server) provides the real limit.
  static const int _defaultSickLeaveTotal = 5;
  int _sickLeaveTotal = _defaultSickLeaveTotal;
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');
  late final DateTime _selectedDate;
  final LeaveRepository _leaveRepo = LeaveRepository(LeaveService());
  final PolicyRepository _policyRepo = PolicyRepository(PolicyService());

  int _sickLeaveUsed = 0;
  int _sickLeaveRemaining = _defaultSickLeaveTotal;
  List<LeaveModel> _myLeaves = <LeaveModel>[];
  String? _workspaceId;
  bool _isLoadingLeaves = true;
  bool _isRefreshing = false;
  bool _scrolledUp = false;
  late final ScrollController _scrollController;

  late String? loggedInUserId;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedFile;
  bool _showValidationErrors = false;
  bool _isSubmitting = false;

  bool get _hasSickLeaveQuota => _sickLeaveRemaining > 0;

  void _showNoQuotaSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('sick_leave_no_remaining_days'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loggedInUserId = _resolveUserId();
    _selectedDate = DateTime.now();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  /// Resolves the workspace, then waits for the policy to be fetched fresh
  /// from the server before loading the leave list, so the screen never
  /// flashes the hardcoded fallback total (or a stale cached value) before
  /// jumping to the real number a moment later.
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoadingLeaves = false);
      return;
    }

    await _fetchPolicyFromServer();
    await _loadData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < -100 &&
        !_scrolledUp &&
        !_isRefreshing) {
      _scrolledUp = true;
      _handleRefresh();
    } else if (_scrollController.position.pixels >= -10) {
      _scrolledUp = false;
    }
  }

  /// Scroll-up-to-refresh for the quota/overlap data backing this form
  /// (matches the homepage/leave-list gesture). Shows SystemLoadingDialog
  /// over the form instead of the initial-load spinner, and always clears
  /// via `finally` so a failed fetch can't leave the non-dismissible dialog
  /// stuck or permanently block further pull-to-refresh attempts.
  Future<void> _handleRefresh() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SystemLoadingDialog(
        title: 'Refreshing...',
        subtitle: 'Getting the latest leave data',
      ),
    );

    try {
      await _fetchPolicyFromServer();
      await _loadData();
    } catch (e) {
      debugPrint('[SickLeaveRequestScreen] refresh error: $e');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _resolveUserId() {
    return (widget.loginData?['uid'] ??
            widget.loginData?['user_id'] ??
            widget.loginData?['userId'] ??
            '')
        .toString()
        .trim();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoadingLeaves = false);
      return;
    }

    // Leave totals come from the workspace policy, cached locally — read it
    // here instead of hardcoding the limit. By the time this runs on
    // initial load, `_loadInitialData` has already awaited a fresh server
    // fetch, so this is normally reading back what that fetch just saved.
    final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
      _workspaceId!,
    );
    _applyPolicyLimit(cachedPolicyMap);

    try {
      final leaves = await _leaveRepo.getMyLeaves(_workspaceId!);
      if (!mounted) return;
      setState(() {
        _myLeaves = leaves;
        _recalculateQuota();
        _isLoadingLeaves = false;
      });
    } catch (e) {
      // The list endpoint is known to be unreliable right now, so fail
      // open with an empty list rather than blocking the request form.
      debugPrint('[SickLeaveRequestScreen] Failed to load leaves: $e');
      if (mounted) setState(() => _isLoadingLeaves = false);
    }
  }

  void _applyPolicyLimit(Map<String, dynamic>? policyMap) {
    final int? sickLimit = _readPositiveInt(policyMap?['sick_leave_limit']);
    if (sickLimit != null) _sickLeaveTotal = sickLimit;
  }

  int? _readPositiveInt(dynamic value) {
    final int? parsed = value is num ? value.toInt() : int.tryParse('$value');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Fetches the policy fresh from the server, updates the local cache
  /// (skipping the write if nothing changed), and refreshes the on-screen
  /// total. Best-effort: falls back to whatever is cached on failure.
  Future<void> _fetchPolicyFromServer() async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) return;

    try {
      final fetchedPolicy = await _policyRepo.getPolicy(workspaceId);
      final policyMap = {
        'id': fetchedPolicy.id,
        'workspace_id': fetchedPolicy.workspaceId,
        'name': fetchedPolicy.name,
        'work_start_time': fetchedPolicy.workStartTime,
        'work_end_time': fetchedPolicy.workEndTime,
        'check_in_start': fetchedPolicy.checkInStart,
        'check_out_start': fetchedPolicy.checkOutStart,
        'late_buffer_minutes': fetchedPolicy.lateBufferMinutes,
        'deadline_scan_minutes': fetchedPolicy.deadlineScanMinutes,
        'annual_leave_limit': fetchedPolicy.annualLeaveLimit,
        'sick_leave_limit': fetchedPolicy.sickLeaveLimit,
        'status': fetchedPolicy.status,
      };

      final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
        workspaceId,
      );
      final bool policyChanged =
          cachedPolicyMap == null ||
          jsonEncode(cachedPolicyMap) != jsonEncode(policyMap);
      if (policyChanged) {
        await DatabaseHelper().saveCachedPolicy(workspaceId, policyMap);
      }

      if (!mounted) return;
      setState(() {
        _applyPolicyLimit(policyMap);
        _recalculateQuota();
      });
    } catch (e) {
      // Policy refresh is best-effort; fall back to whatever is cached.
      debugPrint('[SickLeaveRequestScreen] Failed to refresh policy: $e');
    }
  }

  void _recalculateQuota() {
    final sickLeaves = _myLeaves
        .where((leave) => leave.leaveType.toLowerCase().contains('sick'))
        .toList();
    _sickLeaveUsed = sickLeaves.fold(
      0,
      (sum, leave) => sum + leave.durationInDays,
    );
    _sickLeaveRemaining = (_sickLeaveTotal - _sickLeaveUsed).clamp(0, 9999);
  }

  Future<void> _pickFileFromGallery() async {
    await _pickImageFromSource(ImageSource.gallery);
  }

  Future<void> _pickFileFromCamera() async {
    await _pickImageFromSource(ImageSource.camera);
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    if (_isSubmitting) return;

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (file == null) {
        return;
      }

      if (!_isAllowedAttachmentFile(file.name)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only PNG and JPG images are allowed.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _pickedFile = file;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('profile_image_upload_failed')}: $e',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    if (!_hasSickLeaveQuota) {
      _showNoQuotaSnackBar();
      return;
    }

    setState(() {
      _showValidationErrors = true;
    });

    final isReasonValid = _formKey.currentState?.validate() ?? false;
    final isFileValid = _pickedFile != null;

    if (!isReasonValid || !isFileValid) {
      return;
    }

    final String? workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr('unable_to_resolve_user_id'),
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    bool submitted = false;
    Object? submitError;
    try {
      await _leaveRepo.createLeave(
        workspaceId,
        leaveType: 'sick',
        reason: _reasonController.text.trim(),
        startDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        attachment: File(_pickedFile!.path),
      );
      submitted = true;
    } catch (e) {
      debugPrint('[SickLeaveRequestScreen] Submit failed: $e');
      submitted = false;
      submitError = e;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.tr('leave_request_submit_failed')}: ${_describeError(submitError)}',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('sick_request_submitted'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    Navigator.pop(context, widget.loginData);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _describeError(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool _isAllowedAttachmentFile(String fileName) {
    final String normalized = fileName.trim().toLowerCase();
    return normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoadingLeaves
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              alignment: Alignment.topCenter,
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _showValidationErrors
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        _buildTopInfoCard(context),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(
                                AppStrings.tr('request_details'),
                                context,
                              ),
                              const SizedBox(height: 15),
                              _buildInputCard(context, [
                                _buildLabel(
                                  AppStrings.tr('reason_for_sickness'),
                                  context,
                                ),
                                _buildTextField(
                                  context: context,
                                  hint: AppStrings.tr('sickness_reason_hint'),
                                  icon: Icons.edit_note,
                                  controller: _reasonController,
                                ),
                                const SizedBox(height: 20),
                                _buildLabel(
                                  AppStrings.tr('leave_date'),
                                  context,
                                ),
                                _buildAutoSelectedDateField(context),
                              ]),
                              const SizedBox(height: 25),
                              _buildSectionTitle(
                                AppStrings.tr('medical_documents'),
                                context,
                              ),
                              const SizedBox(height: 15),
                              _buildUploadArea(context),
                              const SizedBox(height: 40),
                              _buildSubmitButton(context),
                              const SizedBox(height: 20),
                            ],
                          ).animate().fadeIn(duration: 600.ms).slideY(
                            begin: 0.1,
                            end: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildPullToRefreshIndicator(),
              ],
            ),
    );
  }

  // Matches the homepage/leave-screen overscroll gesture.
  Widget _buildPullToRefreshIndicator() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        if (!_scrollController.hasClients) return const SizedBox.shrink();

        double overscroll = _scrollController.position.pixels < 0
            ? -_scrollController.position.pixels
            : 0.0;

        if (overscroll <= 0 || _isRefreshing) {
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0.5,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        AppStrings.tr('request_sick_leave_title'),
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildTopInfoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  Icons.medical_services,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.tr('leave_type'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    AppStrings.tr('sick_leave'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceInfo(
                  'Used',
                  '$_sickLeaveUsed days',
                  Colors.orange,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
                _buildBalanceInfo(
                  'Remaining',
                  '$_sickLeaveRemaining days',
                  Colors.green,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
                _buildBalanceInfo(
                  'Total',
                  '$_sickLeaveTotal days',
                  Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildBalanceInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAutoSelectedDateField(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.tr('leave_date'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dateFormatter.format(_selectedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          Icon(
            Icons.today_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildUploadArea(BuildContext context) {
    final hasError = _showValidationErrors && _pickedFile == null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_pickedFile != null) {
      // Show attached file state
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.08),
                  Colors.green.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, size: 40, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  _pickedFile?.name ?? 'Document',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildCardButton(
                        context,
                        Icons.camera_alt_outlined,
                        'Camera',
                        primaryColor,
                        _pickFileFromCamera,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCardButton(
                        context,
                        Icons.image_outlined,
                        'Gallery',
                        primaryColor,
                        _pickFileFromGallery,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().scale(delay: 400.ms),
        ],
      );
    }

    // Show upload prompt with 2 cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCardButton(
                context,
                Icons.image_outlined,
                'Gallery',
                primaryColor,
                _pickFileFromGallery,
                isError: hasError,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCardButton(
                context,
                Icons.camera_alt_outlined,
                'Camera',
                primaryColor,
                _pickFileFromCamera,
                isError: hasError,
              ),
            ),
          ],
        ).animate().scale(delay: 300.ms),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppStrings.tr('validation_upload_medical_document'),
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCardButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed, {
    bool isError = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isError
                ? Colors.red.withOpacity(0.4)
                : color.withOpacity(0.15),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isError
                  ? Colors.red.withOpacity(0.05)
                  : color.withOpacity(0.05),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || !_hasSickLeaveQuota)
            ? null
            : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                AppStrings.tr('submit_official_request'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _buildLabel(String text, BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
      ),
    ),
  );

  Widget _buildSectionTitle(String text, BuildContext context) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    ),
  );

  Widget _buildTextField({
    required BuildContext context,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Theme.of(context).colorScheme.primary,
          selectionHandleColor: Theme.of(context).colorScheme.primary,
          selectionColor: (Theme.of(
            context,
          ).colorScheme.primary).withValues(alpha: 0.2),
        ),
      ),
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return AppStrings.tr('validation_reason_required_sickness');
          }
          if (value.trim().length < 5) {
            return AppStrings.tr('validation_reason_min_chars');
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey),
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
        ),
      ),
    );
  }
}
