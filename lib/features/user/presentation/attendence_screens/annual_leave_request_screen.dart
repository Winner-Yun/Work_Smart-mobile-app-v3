import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:intl/intl.dart';

class AnnualLeaveRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const AnnualLeaveRequestScreen({super.key, this.loginData});

  @override
  State<AnnualLeaveRequestScreen> createState() =>
      _AnnualLeaveRequestScreenState();
}

class _AnnualLeaveRequestScreenState extends State<AnnualLeaveRequestScreen> {
  static const int _annualLeaveTotal = 18;
  late int _annualLeaveUsed;
  late int _annualLeaveRemaining;
  late UserProfile _currentUser;
  late String? loggedInUserId;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDurationRequest = false;
  bool _showValidationErrors = false;
  bool _isSubmitting = false;
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  bool get _hasAnnualLeaveQuota => _annualLeaveRemaining > 0;

  int get _selectedDurationDays {
    if (_startDate == null) return 0;
    if (!_isDurationRequest) return 1;
    if (_endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  void _showNoQuotaSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('annual_leave_no_remaining_days'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showDurationExceedsRemainingSnackBar(int requestedDays) {
    if (!mounted) return;
    final String message =
        AppStrings.tr('annual_leave_duration_exceeds_remaining')
            .replaceAll('{requestedDays}', requestedDays.toString())
            .replaceAll('{remainingDays}', _annualLeaveRemaining.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showDateAlreadyRequestedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('leave_date_already_requested'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showDateRangeAlreadyRequestedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('leave_range_already_requested'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showEndDateMustBeAfterStartSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('annual_leave_end_date_must_be_after_start'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showNoAvailableDatesSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.tr('leave_no_available_dates'),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _isDateAlreadyRequested(DateTime date) {
    return LeaveRequestLogic.isDateRangeOverlappingExisting(
      startDate: date,
      endDate: date,
      existingRecords: _currentUser.leaveRecords,
    );
  }

  bool _doesRangeOverlapRequested(DateTime startDate, DateTime endDate) {
    return LeaveRequestLogic.isDateRangeOverlappingExisting(
      startDate: startDate,
      endDate: endDate,
      existingRecords: _currentUser.leaveRecords,
    );
  }

  @override
  void initState() {
    super.initState();
    loggedInUserId = _resolveUserId();
    _loadData();
  }

  String _resolveUserId() {
    return (widget.loginData?['uid'] ??
            widget.loginData?['user_id'] ??
            widget.loginData?['userId'] ??
            '')
        .toString()
        .trim();
  }

  void _loadData() {
    final String userId = loggedInUserId ?? _resolveUserId();
    final Map<String, dynamic> currentUserData = userId.isEmpty
        ? defaultUserRecord
        : usersFinalData.firstWhere(
            (user) =>
                (user['uid'] ?? user['user_id'] ?? user['userId'])
                    ?.toString()
                    .trim() ==
                userId,
            orElse: () => defaultUserRecord,
          );

    _currentUser = UserProfile.fromJson(currentUserData);

    // Calculate annual leave used from leave records - sum actual days, not record count
    final annualLeaves = _currentUser.leaveRecords
        .where(
          (leave) =>
              leave.type.toLowerCase().contains('annual') ||
              leave.type.toLowerCase().contains('casual'),
        )
        .toList();
    _annualLeaveUsed = annualLeaves.fold(
      0,
      (sum, leave) => sum + leave.durationInDays,
    );
    _annualLeaveRemaining = (_annualLeaveTotal - _annualLeaveUsed).clamp(
      0,
      9999,
    );
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    if (!_hasAnnualLeaveQuota) {
      _showNoQuotaSnackBar();
      return;
    }

    setState(() {
      _showValidationErrors = true;
    });

    final isReasonValid = _formKey.currentState?.validate() ?? false;
    final hasValidDateRange =
        _startDate != null && (!_isDurationRequest || _endDate != null);
    final requestedDays = _selectedDurationDays;
    final DateTime? effectiveEndDate = _isDurationRequest
        ? _endDate
        : _startDate;

    if (!isReasonValid || !hasValidDateRange) {
      return;
    }

    if (_isDurationRequest && !effectiveEndDate!.isAfter(_startDate!)) {
      _showEndDateMustBeAfterStartSnackBar();
      return;
    }

    if (_doesRangeOverlapRequested(_startDate!, effectiveEndDate!)) {
      _showDateRangeAlreadyRequestedSnackBar();
      return;
    }

    if (requestedDays <= 0 || requestedDays > _annualLeaveRemaining) {
      _showDurationExceedsRemainingSnackBar(requestedDays);
      return;
    }

    final String userId = _resolveUserId().isNotEmpty
        ? _resolveUserId()
        : _currentUser.uid.trim();
    if (userId.isEmpty) {
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

    final bool submitted = await LeaveRequestLogic.submitLeaveRequest(
      userId: userId,
      type: 'annual_leave',
      startDate: _startDate!,
      endDate: effectiveEndDate,
      reason: _reasonController.text,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr('leave_request_submit_failed'),
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
          AppStrings.tr('annual_request_submitted'),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: _showValidationErrors
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(context),
              const SizedBox(height: 25),
              _buildSectionTitle(AppStrings.tr('select_date'), context),
              const SizedBox(height: 15),
              _buildRequestTypeToggle(context),
              const SizedBox(height: 12),
              Text(
                AppStrings.tr('annual_leave_date_mode_hint'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 10),
              _buildDateRangePicker(context),
              const SizedBox(height: 25),
              _buildSectionTitle(AppStrings.tr('reason_for_request'), context),
              const SizedBox(height: 15),
              _buildTextArea(context),
              const SizedBox(height: 40),
              _buildSubmitButton(context),
            ],
          ).animate().fadeIn(duration: 500.ms),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
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
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.teal.withOpacity(0.1),
                child: const Icon(Icons.calendar_today, color: Colors.teal),
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
                    AppStrings.tr('annual_leave'),
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
              color: Colors.teal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceInfo(
                  AppStrings.tr('used'),
                  '$_annualLeaveUsed ${AppStrings.tr('days')}',
                  Colors.orange,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                ),
                _buildBalanceInfo(
                  AppStrings.tr('remaining'),
                  '$_annualLeaveRemaining ${AppStrings.tr('days')}',
                  Colors.green,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                ),
                _buildBalanceInfo(
                  AppStrings.tr('total_leave_label'),
                  '$_annualLeaveTotal ${AppStrings.tr('days')}',
                  Colors.teal,
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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

  Widget _buildDateRangePicker(BuildContext context) {
    final hasError =
        _showValidationErrors &&
        (_startDate == null || (_isDurationRequest && _endDate == null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? Colors.red
                  : Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              _dateColumn(
                context,
                _isDurationRequest
                    ? AppStrings.tr('start_date')
                    : AppStrings.tr('select_date'),
                _startDate == null
                    ? AppStrings.tr('select_date')
                    : _dateFormatter.format(_startDate!),
                onTap: () => _pickStartDate(context),
              ),
              if (_isDurationRequest) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
                _dateColumn(
                  context,
                  AppStrings.tr('end_date'),
                  _endDate == null
                      ? AppStrings.tr('select_date')
                      : _dateFormatter.format(_endDate!),
                  onTap: _startDate == null
                      ? null
                      : () => _pickEndDate(context),
                ),
              ],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              AppStrings.tr('validation_select_start_end_date'),
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestTypeToggle(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDurationRequest
              ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
              : Theme.of(context).dividerColor.withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isDurationRequest
                      ? Icons.date_range_rounded
                      : Icons.today_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr('annual_leave_duration_toggle_title'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isDurationRequest
                          ? AppStrings.tr(
                              'annual_leave_duration_toggle_subtitle_duration',
                            )
                          : AppStrings.tr(
                              'annual_leave_duration_toggle_subtitle_single',
                            ),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: _isDurationRequest,
                onChanged: (value) {
                  setState(() {
                    _isDurationRequest = value ?? false;
                    if (!_isDurationRequest) {
                      _endDate = _startDate;
                    } else if (_startDate != null &&
                        _endDate != null &&
                        !_endDate!.isAfter(_startDate!)) {
                      _endDate = null;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildModeChip(
                context,
                icon: Icons.today,
                label: AppStrings.tr('annual_leave_mode_single_day'),
                selected: !_isDurationRequest,
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                context,
                icon: Icons.date_range,
                label: AppStrings.tr('annual_leave_mode_duration'),
                selected: _isDurationRequest,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Theme.of(context).dividerColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                : Theme.of(context).dividerColor.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).iconTheme.color?.withOpacity(0.65),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateColumn(
    BuildContext context,
    String label,
    String date, {
    VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey.shade400 : Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                date,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDisabled
                      ? Colors.grey.shade400
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate(BuildContext context) async {
    if (!_hasAnnualLeaveQuota) {
      _showNoQuotaSnackBar();
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year, now.month, now.day);
    final DateTime lastDate = DateTime(now.year + 2, now.month, now.day);
    final DateTime? initialDate = LeaveRequestLogic.findInitialSelectableDate(
      preferredDate: _startDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) => !_isDateAlreadyRequested(date),
    );

    if (initialDate == null) {
      _showNoAvailableDatesSnackBar();
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) => !_isDateAlreadyRequested(date),
    );

    if (picked == null) return;

    if (_isDateAlreadyRequested(picked)) {
      _showDateAlreadyRequestedSnackBar();
      return;
    }

    setState(() {
      _startDate = picked;
      if (!_isDurationRequest) {
        _endDate = _startDate;
      } else {
        if (_endDate != null && !_endDate!.isAfter(_startDate!)) {
          _endDate = null;
        }

        if (_endDate != null && _selectedDurationDays > _annualLeaveRemaining) {
          _endDate = null;
        }

        if (_endDate != null &&
            _doesRangeOverlapRequested(_startDate!, _endDate!)) {
          _endDate = null;
        }
      }
    });
  }

  Future<void> _pickEndDate(BuildContext context) async {
    if (_startDate == null) return;
    if (!_hasAnnualLeaveQuota) {
      _showNoQuotaSnackBar();
      return;
    }

    final DateTime minEndDate = _startDate!.add(const Duration(days: 1));

    final DateTime maxByQuota = _startDate!.add(
      Duration(days: _annualLeaveRemaining - 1),
    );
    final DateTime maxByPolicy = DateTime(_startDate!.year + 2);
    final DateTime lastDate = maxByQuota.isBefore(maxByPolicy)
        ? maxByQuota
        : maxByPolicy;

    if (lastDate.isBefore(minEndDate)) {
      _showEndDateMustBeAfterStartSnackBar();
      return;
    }

    DateTime initial = _endDate ?? minEndDate;
    if (initial.isBefore(minEndDate)) {
      initial = minEndDate;
    }
    final DateTime firstDate = minEndDate;
    final DateTime? initialDate = LeaveRequestLogic.findInitialSelectableDate(
      preferredDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) =>
          date.isAfter(_startDate!) &&
          !_doesRangeOverlapRequested(_startDate!, date),
    );

    if (initialDate == null) {
      _showDateRangeAlreadyRequestedSnackBar();
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) =>
          date.isAfter(_startDate!) &&
          !_doesRangeOverlapRequested(_startDate!, date),
    );

    if (picked == null) return;

    if (!picked.isAfter(_startDate!)) {
      _showEndDateMustBeAfterStartSnackBar();
      return;
    }

    if (_doesRangeOverlapRequested(_startDate!, picked)) {
      _showDateRangeAlreadyRequestedSnackBar();
      return;
    }

    setState(() {
      _endDate = picked;
    });
  }

  Widget _buildTextArea(BuildContext context) {
    return TextFormField(
      controller: _reasonController,
      maxLines: 5,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return AppStrings.tr('validation_reason_required_request');
        }
        if (value.trim().length < 5) {
          return AppStrings.tr('validation_reason_min_chars');
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: AppStrings.tr('enter_reason_hint'),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0.5,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: Theme.of(context).iconTheme.color,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        AppStrings.tr('request_annual_leave_title'),
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSectionTitle(String text, BuildContext context) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    ),
  );

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: (_isSubmitting || !_hasAnnualLeaveQuota)
            ? null
            : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
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
                AppStrings.tr('submit_request'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
