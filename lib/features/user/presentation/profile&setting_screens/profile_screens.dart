import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/cloudinary/cloudinary_profile_image_service.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/presentation/profile&setting_screens/setting_screen.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:flutter_worksmart_app/shared/widget/common/app_profile_avatar.dart';
import 'package:flutter_worksmart_app/shared/widget/common/profile_skeleton_loading.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const ProfileScreen({super.key, this.loginData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _currentUser = UserProfile.fromJson(const <String, dynamic>{});
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final RealtimeDataController _dataController = RealtimeDataController();
  final CloudinaryProfileImageService _cloudinaryProfileImageService =
      CloudinaryProfileImageService();
  bool _isUploadingProfileImage = false;
  bool _isLoading = true;
  String? _resolvedOfficeName;

  @override
  void initState() {
    super.initState();
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

  bool _matchesUserId(Map<String, dynamic> user, String userId) {
    if (userId.isEmpty) return false;

    final String candidateId =
        (user['uid'] ?? user['user_id'] ?? user['userId'] ?? '')
            .toString()
            .trim();
    return candidateId == userId;
  }

  Future<void> _loadData() async {
    final String userId = _resolveUserId();

    Map<String, dynamic> currentUserData = userId.isEmpty
        ? defaultUserRecord
        : usersFinalData.firstWhere(
            (user) => _matchesUserId(user, userId),
            orElse: () => defaultUserRecord,
          );

    if (currentUserData.isEmpty && userId.isNotEmpty) {
      final fetchedUser = await _dataController.fetchUserRecordById(userId);
      if (fetchedUser != null) {
        currentUserData = fetchedUser;
        final int userIndex = usersFinalData.indexWhere(
          (user) => _matchesUserId(user, userId),
        );
        if (userIndex != -1) {
          usersFinalData[userIndex] = Map<String, dynamic>.from(fetchedUser);
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _currentUser = UserProfile.fromJson(currentUserData);
      final inlineOfficeName =
          (currentUserData['office_name'] ??
                  currentUserData['officeName'] ??
                  '')
              .toString()
              .trim();
      _resolvedOfficeName = inlineOfficeName.isEmpty ? null : inlineOfficeName;
    });

    await _loadOfficeName();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOfficeName() async {
    final officeId = _currentUser.officeId.trim();
    if (officeId.isEmpty) {
      if (!mounted) {
        _resolvedOfficeName = null;
        return;
      }
      setState(() => _resolvedOfficeName = null);
      return;
    }

    try {
      final office = await _dataController.fetchOfficeConnection(
        officeId: officeId,
      );
      final officeName = (office?['office_name'] ?? office?['officeName'] ?? '')
          .toString()
          .trim();
      if (officeName.isEmpty) {
        return;
      }

      if (!mounted) {
        _resolvedOfficeName = officeName;
        return;
      }

      setState(() => _resolvedOfficeName = officeName);
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingProfileImage) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        setState(() => _image = imageFile);
        await _uploadAndSaveProfileImage(imageFile);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _uploadAndSaveProfileImage(File imageFile) async {
    final String userId = _currentUser.uid.trim();
    if (userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('unable_to_resolve_user_id'))),
      );
      return;
    }

    setState(() => _isUploadingProfileImage = true);

    try {
      final String imageUrl = await _cloudinaryProfileImageService
          .uploadProfileImage(
            imageFile: imageFile,
            userId: userId,
            previousImageUrl: _currentUser.profileUrl,
          );

      await _dataController.updateUserRecord(userId, {'profile_url': imageUrl});

      final int userIndex = usersFinalData.indexWhere(
        (user) => user['uid']?.toString().trim() == userId,
      );
      if (userIndex != -1) {
        usersFinalData[userIndex]['profile_url'] = imageUrl;
      }

      if (!mounted) return;
      setState(() {
        _image = null;
        _isLoading = true;
      });
      _loadData();

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
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfileImage = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const ProfileSkeletonLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildAvatarSection(),
                  const SizedBox(height: 15),
                  Text(
                    _currentUser.displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
                  Text(
                    _currentUser.roleTitle,
                    style: const TextStyle(color: AppColors.textGrey),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 30),
                  _buildInfoCard(context),
                  const SizedBox(height: 20),
                  _buildActionTile(
                    Icons.lock_outline,
                    AppStrings.tr('change_password_action'),
                    context,
                  ),
                  const SizedBox(height: 30),
                  _buildLogoutButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      title: Text(
        AppStrings.tr('account_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            onPressed: () async {
              final shouldRefresh = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(loginData: widget.loginData),
                ),
              );
              if (!mounted) return;
              if (shouldRefresh == true) {
                setState(() => _isLoading = true);
                _loadData();
              }
            },
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
          ),
        ),
      ],
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

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              color: AppColors.textGrey.withValues(alpha: 0.3),
            ),
            child: _image != null
                ? ClipOval(child: Image.file(_image!, fit: BoxFit.cover))
                : AppProfileAvatar(
                    displayName: _currentUser.displayName,
                    imageUrl: _currentUser.profileUrl,
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textColor: Theme.of(context).colorScheme.primary,
                    fontSize: 28,
                  ),
          ),
          if (_isUploadingProfileImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.35),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
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
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _isUploadingProfileImage
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary,
              child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms);
  }

  Widget _buildInfoCard(BuildContext context) {
    // final bool isPhoneMissing = _currentUser.phone.trim().isEmpty;
    // final String phoneValue = isPhoneMissing
    //     ? AppStrings.tr('not_available')
    //     : _currentUser.phone;
    final officeDisplayValue = _resolvedOfficeName?.trim().isNotEmpty == true
        ? _resolvedOfficeName!.trim()
        : _currentUser.officeId.trim();
    final bool isOfficeMissing = officeDisplayValue.isEmpty;
    final String officeValue = isOfficeMissing
        ? AppStrings.tr('not_available')
        : officeDisplayValue;
    final bool isDepartmentMissing = _currentUser.departmentId.trim().isEmpty;
    final String departmentValue = isDepartmentMissing
        ? AppStrings.tr('not_available')
        : _currentUser.departmentId.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          // _buildInfoRow(
          //   context,
          //   Icons.phone_outlined,
          //   AppStrings.tr('phone_label'),
          //   phoneValue,
          //   valueColor: isPhoneMissing ? Colors.red.shade400 : null,
          // ),
          // const Divider(height: 30, thickness: 0.5),
          _buildInfoRow(
            context,
            Icons.apartment_rounded,
            AppStrings.tr('office_label'),
            officeValue,
            valueColor: isOfficeMissing ? Colors.red.shade400 : null,
          ),
          const Divider(height: 30, thickness: 0.5),
          _buildInfoRow(
            context,
            Icons.business_center_outlined,
            AppStrings.tr('department_label'),
            departmentValue,
            valueColor: isDepartmentMissing ? Colors.red.shade400 : null,
          ),
          // const Divider(height: 30, thickness: 0.5),
          // _buildTelegramStatus(context),
          const Divider(height: 30, thickness: 0.5),
          _buildInfoRow(
            context,
            Icons.email_outlined,
            AppStrings.tr('email_label'),
            _currentUser.email,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // Widget _buildTelegramStatus(BuildContext context) {
  //   final bool isConnected = _currentUser.telegram.isConnected;
  //   final String telegramLabel = isConnected
  //       ? AppStrings.tr('connected')
  //       : AppStrings.tr('not_connected');
  //   return Row(
  //     children: [
  //       CircleAvatar(
  //         backgroundColor: Colors.blue.shade50,
  //         child: Icon(
  //           Icons.send,
  //           color: Theme.of(context).colorScheme.primary,
  //           size: 20,
  //         ),
  //       ),
  //       const SizedBox(width: 15),
  //       Expanded(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text(
  //               'Telegram',
  //               style: TextStyle(color: AppColors.textGrey, fontSize: 12),
  //             ),
  //             Text(
  //               telegramLabel,
  //               maxLines: 1,
  //               overflow: TextOverflow.ellipsis,
  //               style: TextStyle(
  //                 color: isConnected
  //                     ? Colors.green.shade600
  //                     : Colors.red.shade400,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       if (!isConnected)
  //         TextButton(
  //           onPressed: () async {
  //             await Navigator.pushNamed(
  //               context,
  //               AppRoute.telegramConfig,
  //               arguments: widget.loginData,
  //             );

  //             if (!mounted) return;
  //             setState(_loadData);
  //           },
  //           style: TextButton.styleFrom(
  //             backgroundColor: Theme.of(
  //               context,
  //             ).colorScheme.primary.withOpacity(0.2),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //           ),
  //           child: Text(
  //             AppStrings.tr('connect_now'),
  //             style: TextStyle(
  //               color: Theme.of(context).colorScheme.primary,
  //               fontWeight: FontWeight.bold,
  //               fontSize: 12,
  //             ),
  //           ),
  //         ),
  //     ],
  //   );
  // }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.textGrey.withValues(alpha: 0.1),
          child: Icon(
            icon,
            color: AppColors.textGrey.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      valueColor ??
                      Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textGrey.withValues(alpha: 0.6)),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textGrey,
            ),
          ],
        ),
      ).animate().fadeIn(delay: 500.ms),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.error),
      ),
      child: InkWell(
        onTap: () {
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
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
                                  // Clear cached login before logout
                                  final dbHelper = DatabaseHelper();
                                  await dbHelper.clearCachedLogin();

                                  if (context.mounted) {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      AppRoute.authScreen,
                                      (route) => false,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
        },
        borderRadius: BorderRadius.circular(15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 10),
            Text(
              AppStrings.tr('logout_action'),
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}
