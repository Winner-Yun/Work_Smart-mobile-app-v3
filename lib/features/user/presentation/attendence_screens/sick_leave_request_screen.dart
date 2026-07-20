import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/cloudinary/cloudinary_profile_image_service.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SickLeaveRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const SickLeaveRequestScreen({super.key, this.loginData});

  @override
  State<SickLeaveRequestScreen> createState() => _SickLeaveRequestScreenState();
}

class _SickLeaveRequestScreenState extends State<SickLeaveRequestScreen> {
  static const int _sickLeaveTotal = 5;
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');
  late final DateTime _selectedDate;
  final CloudinaryProfileImageService _cloudinaryImageService =
      CloudinaryProfileImageService();
  late int _sickLeaveUsed;
  late int _sickLeaveRemaining;
  late UserProfile _currentUser;
  late String? loggedInUserId;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedFile;
  String? _attachmentUrl;
  bool _isUploadingAttachment = false;
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
    final currentUserData = usersFinalData.firstWhere(
      (user) =>
          (user['uid'] ?? user['user_id'] ?? user['userId'])
              ?.toString()
              .trim() ==
          (loggedInUserId ?? _resolveUserId()),
      orElse: () => defaultUserRecord,
    );
    _currentUser = UserProfile.fromJson(currentUserData);

    // Calculate sick leave used from leave records - sum actual days, not record count
    final sickLeaves = _currentUser.leaveRecords
        .where((leave) => leave.type.toLowerCase().contains('sick'))
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
    if (_isSubmitting || _isUploadingAttachment) return;

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

      final String filePath = file.path.trim();
      if (filePath.isEmpty) {
        if (!mounted) return;
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

      final String userId = _resolveUserId().isNotEmpty
          ? _resolveUserId()
          : _currentUser.uid.trim();
      if (userId.isEmpty) {
        if (!mounted) return;
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
        _isUploadingAttachment = true;
      });

      final String uploadedUrl = await _cloudinaryImageService
          .uploadLeaveAttachment(
            imageFile: File(filePath),
            userId: userId,
            previousImageUrl: _attachmentUrl,
          );

      if (!mounted) return;

      setState(() {
        _pickedFile = file;
        _attachmentUrl = uploadedUrl;
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
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
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
    final isDateValid = true;
    final isFileValid = _attachmentUrl != null;

    if (!isReasonValid || !isDateValid || !isFileValid) {
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
      type: 'sick_leave',
      startDate: _selectedDate,
      endDate: _selectedDate,
      reason: _reasonController.text,
      attachmentUrl: _attachmentUrl,
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
    super.dispose();
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
      body: SingleChildScrollView(
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
                      _buildLabel(AppStrings.tr('leave_date'), context),
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
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
              ),
            ],
          ),
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
    final hasError = _showValidationErrors && _attachmentUrl == null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_attachmentUrl != null) {
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
                if (_isUploadingAttachment)
                  const SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.green),
                    ),
                  )
                else
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
        if (_isUploadingAttachment)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
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
        onPressed:
            (_isSubmitting || _isUploadingAttachment || !_hasSickLeaveQuota)
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
