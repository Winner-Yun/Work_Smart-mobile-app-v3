import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/logic/update_face_flow_controller.dart';
import 'package:flutter_worksmart_app/features/user/repository/profile_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/workspace_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/profile_service.dart';
import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/service/workspace_service.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/app_profile_avatar.dart';
import 'package:flutter_worksmart_app/shared/widget/common/profile_skeleton_loading.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  // Hidden while no workspace is selected — Update Face needs that context.
  final bool hasWorkspace;

  const ProfileScreen({super.key, this.loginData, this.hasWorkspace = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserRepository _userRepo = UserRepository(UserService());
  final ProfileRepository _profileRepo = ProfileRepository(ProfileService());
  final WorkspaceRepository _workspaceRepo = WorkspaceRepository(
    WorkspaceService(),
  );
  final ImagePicker _picker = ImagePicker();

  UserModel? _currentUser;
  String? _workspaceName;
  File? _image;
  bool _isUploadingProfileImage = false;
  bool _isLoading = true;
  bool _isUpdatingNotification = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {}
  }

  Future<void> _handleLanguageChange(String langCode) async {
    if (LanguageManager().locale == langCode) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    await LanguageManager().changeLanguage(langCode);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (_isUpdatingNotification) return;
    setState(() => _isUpdatingNotification = true);

    try {
      final UserModel updated = await _userRepo.updateAllowNotification(value);
      await DatabaseHelper().saveUserProfile(updated.toJson());
      if (!mounted) return;
      setState(() {
        _currentUser = updated;
        _isUpdatingNotification = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('notification_update_failed')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Cache-first: show cached data immediately, refresh in the background; only a cold start waits.
  Future<void> _loadData() async {
    final cached = await DatabaseHelper().getUserProfile();
    if (cached != null) {
      _currentUser = UserModel.fromJson(cached);
    }

    final bool hasLocalData = _currentUser != null;

    if (hasLocalData) {
      unawaited(_loadWorkspaceName());
      // Keep skeleton up briefly so it doesn't read as a jarring instant pop-in.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (mounted) {
        setState(() => _isLoading = false);
      }
      unawaited(_refreshProfileFromServer());
    } else {
      await _loadWorkspaceName();
      await _refreshProfileFromServer();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshProfileFromServer() async {
    try {
      final UserModel user = await _userRepo.getUserProfile();
      await DatabaseHelper().saveUserProfile(user.toJson());
      final bool changed =
          _currentUser == null ||
          jsonEncode(user.toJson()) != jsonEncode(_currentUser!.toJson());
      _currentUser = user;
      if (changed && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadWorkspaceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? selectedId = prefs.getString('selected_workspace_id');

      if (selectedId == null || selectedId.isEmpty) {
        // Don't fall back to a cached name — the user may have left/switched workspaces.
        if (mounted) setState(() => _workspaceName = null);
        return;
      }

      final String? cachedJson = prefs.getString('cached_selected_workspace');
      if (cachedJson != null) {
        final Workspace cached = Workspace.fromJson(jsonDecode(cachedJson));
        if (cached.id == selectedId) {
          if (mounted) setState(() => _workspaceName = cached.workspaceName);
          return;
        }
      }

      final List<Workspace> workspaces = await _workspaceRepo.getWorkspaces();
      if (workspaces.isEmpty) return;

      Workspace? match;
      for (final workspace in workspaces) {
        if (workspace.id == selectedId) {
          match = workspace;
          break;
        }
      }
      match ??= workspaces.first;

      if (mounted) setState(() => _workspaceName = match!.workspaceName);
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingProfileImage) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final File? croppedFile = await _cropProfileImage(pickedFile.path);
      if (croppedFile == null) return;

      setState(() => _image = croppedFile);
      await _uploadProfileImage(croppedFile);
    } catch (_) {}
  }

  Future<File?> _cropProfileImage(String sourcePath) async {
    final Color primary = Theme.of(context).colorScheme.primary;
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      maxWidth: 1000,
      maxHeight: 1000,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: AppStrings.tr('crop_profile_photo'),
          toolbarColor: primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: primary,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: AppStrings.tr('crop_profile_photo'),
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() => _isUploadingProfileImage = true);

    try {
      await _profileRepo.updateProfileImage(imageFile);
      await _loadData();

      if (!mounted) return;
      setState(() => _image = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('profile_image_updated_successfully')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('profile_image_upload_failed')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfileImage = false);
      }
    }
  }

  String _normalizeGender(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized == 'male' || normalized == 'female') {
      return normalized;
    }
    return 'other';
  }

  Future<bool> _saveProfileChanges({
    required String name,
    required String gender,
  }) async {
    try {
      final UserModel updated = await _userRepo.updateProfile(
        name: name,
        gender: gender,
      );
      await DatabaseHelper().saveUserProfile(updated.toJson());
      if (!mounted) return false;
      setState(() => _currentUser = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr('profile_updated_successfully')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('profile_update_failed')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
  }

  Future<void> _showEditProfileSheet() async {
    final TextEditingController nameController = TextEditingController(
      text: _currentUser?.name ?? '',
    );
    String selectedGender = _normalizeGender(_currentUser?.gender);
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    AppStrings.tr('edit_profile_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.tr('name_label'),
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.tr('gender_label'),
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      _genderChip(
                        'male',
                        selectedGender,
                        AppStrings.tr('gender_male'),
                        (value) => setSheetState(() => selectedGender = value),
                      ),
                      _genderChip(
                        'female',
                        selectedGender,
                        AppStrings.tr('gender_female'),
                        (value) => setSheetState(() => selectedGender = value),
                      ),
                      _genderChip(
                        'other',
                        selectedGender,
                        AppStrings.tr('gender_other'),
                        (value) => setSheetState(() => selectedGender = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final String name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppStrings.tr('name_required'),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              final bool success = await _saveProfileChanges(
                                name: name,
                                gender: selectedGender,
                              );
                              if (!sheetContext.mounted) return;
                              setSheetState(() => isSaving = false);
                              if (success) Navigator.of(sheetContext).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppStrings.tr('save_button'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _genderChip(
    String value,
    String selectedValue,
    String label,
    ValueChanged<String> onSelected,
  ) {
    final bool selected = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
        ),
      ),
    );
  }

  Future<void> _performLogout() async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 3,
          ),
        ),
      ),
    );

    try {
      final cachedLogin = await DatabaseHelper().getCachedLogin();
      final String refreshToken = (cachedLogin?['refresh_token'] ?? '')
          .toString();
      if (refreshToken.isNotEmpty) {
        await _userRepo.logout(refreshToken);
      }
    } catch (_) {} finally {
      // Wipe local data even if server logout failed, so the user must log in again.
      await DatabaseHelper().clearAllUserData();
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoute.authScreen,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeManager(), LanguageManager()]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(context),
          body: _isLoading
              ? const ProfileSkeletonLoading()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildProfileHeader(context),
                      const SizedBox(height: 22),
                      _buildSectionLabel(AppStrings.tr('general_section')),
                      _buildSettingsGroup(context, [
                        _buildToggleRow(
                          context,
                          Icons.dark_mode_rounded,
                          AppStrings.tr('dark_mode'),
                          Colors.purple,
                          ThemeManager().isDarkMode,
                          (value) => ThemeManager().toggleTheme(value),
                        ),
                        _buildDivider(context),
                        _buildToggleRow(
                          context,
                          Icons.notifications_active_rounded,
                          AppStrings.tr('notification_label'),
                          Colors.orange,
                          _currentUser?.allowNotification ?? true,
                          _handleNotificationToggle,
                          isLoading: _isUpdatingNotification,
                        ),
                        _buildDivider(context),
                        _buildLanguageRow(context),
                      ]),
                      const SizedBox(height: 22),
                      _buildSectionLabel(AppStrings.tr('support_section')),
                      _buildSettingsGroup(context, [
                        _buildNavRow(
                          context,
                          Icons.edit_outlined,
                          AppStrings.tr('edit_profile_action'),
                          Theme.of(context).colorScheme.primary,
                          onTap: _showEditProfileSheet,
                        ),
                        _buildDivider(context),
                        if (widget.hasWorkspace) ...[
                          _buildNavRow(
                            context,
                            Icons.face_retouching_natural_rounded,
                            AppStrings.tr('update_face_action'),
                            Colors.teal,
                            onTap: () => UpdateFaceFlowController.start(
                              context,
                              loginData: widget.loginData,
                            ),
                          ),
                          _buildDivider(context),
                        ],
                        _buildNavRow(
                          context,
                          Icons.headset_mic_rounded,
                          AppStrings.tr('help_support_title'),
                          Colors.blue,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoute.helpSupportScreen,
                          ),
                        ),
                        _buildDivider(context),
                        _buildNavRow(
                          context,
                          Icons.auto_awesome_motion_rounded,
                          AppStrings.tr('about_app'),
                          Colors.indigo,
                          trailing: Text(
                            _appVersion!,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildNavRow(
                          context,
                          Icons.logout_rounded,
                          AppStrings.tr('logout_action'),
                          Colors.red.shade400,
                          labelColor: Colors.red.shade400,
                          showChevron: false,
                          onTap: _confirmLogout,
                        ),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        AppStrings.tr('account_title'),
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      iconTheme: Theme.of(context).iconTheme,
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                AppStrings.tr('choose_photo'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionItem(
                    context,
                    icon: Icons.photo_library_rounded,
                    label: AppStrings.tr('gallery'),
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildOptionItem(
                    context,
                    icon: Icons.camera_alt_rounded,
                    label: AppStrings.tr('camera'),
                    color: AppColors.secondary,
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final bool isWorkspaceMissing =
        _workspaceName == null || _workspaceName!.trim().isEmpty;
    final String workspaceValue = isWorkspaceMissing
        ? AppStrings.tr('not_available')
        : _workspaceName!.trim();
    final genderInfo = _genderDisplay(_currentUser?.gender);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 76,
                    width: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      color: AppColors.textGrey.withValues(alpha: 0.15),
                    ),
                    child: _image != null
                        ? ClipOval(
                            child: Image.file(_image!, fit: BoxFit.cover),
                          )
                        : AppProfileAvatar(
                            displayName: _currentUser?.name ?? '',
                            imageUrl: _currentUser?.avatar ?? '',
                            radius: 37,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            textColor: Theme.of(context).colorScheme.primary,
                            fontSize: 20,
                          ),
                  ),
                  if (_isUploadingProfileImage)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _isUploadingProfileImage
                        ? null
                        : () => _showPickerOptions(context),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Theme.of(context).cardTheme.color ?? Colors.white,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: _isUploadingProfileImage
                            ? AppColors.textGrey
                            : Theme.of(context).colorScheme.primary,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().scale(duration: 400.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isWorkspaceMissing
                              ? Icons.warning_amber_rounded
                              : Icons.apartment_rounded,
                          size: 13,
                          color: isWorkspaceMissing
                              ? Colors.red.shade400
                              : AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            workspaceValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isWorkspaceMissing
                                  ? Colors.red.shade400
                                  : AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          const SizedBox(height: 14),
          _buildContactLine(Icons.email_outlined, _currentUser?.email ?? ''),
          const SizedBox(height: 12),
          _buildContactLine(
            genderInfo.icon,
            genderInfo.label,
            iconColor: genderInfo.color,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildContactLine(IconData icon, String value, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? AppColors.textGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  ({IconData icon, String label, Color color}) _genderDisplay(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'male':
        return (
          icon: Icons.male_rounded,
          label: AppStrings.tr('gender_male'),
          color: const Color(0xFF3B82F6),
        );
      case 'female':
        return (
          icon: Icons.female_rounded,
          label: AppStrings.tr('gender_female'),
          color: const Color(0xFFEC4899),
        );
      case 'other':
        return (
          icon: Icons.person_outline_rounded,
          label: AppStrings.tr('gender_other'),
          color: AppColors.secondary,
        );
      default:
        return (
          icon: Icons.help_outline_rounded,
          label: AppStrings.tr('gender_unknown'),
          color: AppColors.textGrey,
        );
    }
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12),
        ],
      ),
      child: Column(children: children),
    ).animate().fadeIn(duration: 420.ms);
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.1),
      indent: 70,
      endIndent: 20,
    );
  }

  Widget _buildSoftIcon(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildToggleRow(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    bool value,
    ValueChanged<bool>? onChanged, {
    bool isLoading = false,
  }) {
    final ValueChanged<bool>? effectiveOnChanged = isLoading ? null : onChanged;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: effectiveOnChanged == null
          ? null
          : () => effectiveOnChanged(!value),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: _buildSoftIcon(context, icon, color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w200,
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (isLoading) const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: effectiveOnChanged,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: _buildSoftIcon(context, Icons.translate_rounded, Colors.teal),
      title: Text(
        AppStrings.tr('language_label'),
        style: TextStyle(
          fontWeight: FontWeight.w200,
          fontSize: 15,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangChip('ខ្មែរ', 'km', context),
            _buildLangChip('EN', 'en', context),
          ],
        ),
      ),
    );
  }

  Widget _buildLangChip(String text, String code, BuildContext context) {
    final bool active = LanguageManager().locale == code;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: active ? null : () => _handleLanguageChange(code),
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active
                ? (isDark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary)
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildNavRow(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
    Widget? trailing,
    Color? labelColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: _buildSoftIcon(context, icon, color),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w200,
            fontSize: 15,
            color: labelColor ?? Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing:
            trailing ??
            (showChevron
                ? Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 24,
                  )
                : null),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 25,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.red.shade50,
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade400,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.tr('confirm_logout_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.tr('confirm_logout_msg'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Text(
                            AppStrings.tr('cancel_button'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _performLogout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppStrings.tr('logout_button'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
      },
    );
  }
}
