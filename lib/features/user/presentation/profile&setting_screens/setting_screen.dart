import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/logic/setting_logic.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const SettingsScreen({super.key, this.loginData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends SettingLogic {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeManager(), LanguageManager()]),
      builder: (context, child) {
        final isDarkMode = ThemeManager().isDarkMode;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(context),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              _buildSectionHeader(AppStrings.tr('general_section')),
              _buildPremiumGroup(context, [
                _buildLanguageTile(context),
                _buildCustomDivider(context),
                _buildGlassSwitchTile(
                  context,
                  Icons.dark_mode_rounded,
                  AppStrings.tr('dark_mode'),
                  Colors.purple,
                  isDarkMode,
                  (value) {
                    ThemeManager().toggleTheme(value);
                  },
                ),
                _buildCustomDivider(context),
                _buildGlassSwitchTile(
                  context,
                  Icons.notifications_active_rounded,
                  AppStrings.tr('notification_label'),
                  Colors.orange,
                  isNotification,
                  isSavingNotification ? null : handleNotificationChange,
                  isLoading: isSavingNotification,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(AppStrings.tr('support_section')),
              _buildPremiumGroup(context, [
                _buildPremiumNavTile(
                  context,
                  Icons.headset_mic_rounded,
                  AppStrings.tr('help_support_title'),
                  Colors.blue,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoute.helpSupportScreen);
                  },
                ),
                _buildCustomDivider(context),
                _buildPremiumNavTile(
                  context,
                  Icons.auto_awesome_motion_rounded,
                  AppStrings.tr('about_app'),
                  Colors.indigo,
                  trailing: Text(
                    'v1.2.4',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 28),
              _buildBrandFooter(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTileContainer({
    required Widget child,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: child,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          onPressed: () => Navigator.pop(context, shouldRefreshOnPop),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).iconTheme.color,
            size: 18,
          ),
        ),
      ),
      title: Text(
        AppStrings.tr('settings_title'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 19,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
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

  Widget _buildPremiumGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    ).animate().fadeIn(duration: 420.ms);
  }

  Widget _buildLanguageTile(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: _buildSoftIcon(context, Icons.translate_rounded, Colors.blue),
      title: Text(
        AppStrings.tr('language_label'),
        style: TextStyle(
          fontWeight: FontWeight.bold,
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
            _buildLangBtn('ខ្មែរ', context),
            _buildLangBtn('EN', context),
          ],
        ),
      ),
    );
  }

  Widget _buildLangBtn(String text, BuildContext context) {
    final String codeToCheck = (text == 'ខ្មែរ') ? 'km' : 'en';
    bool active = LanguageManager().locale == codeToCheck;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (!active) {
          handleLanguageChange(context, codeToCheck);
        }
      },
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
                ? (isDark ? Colors.white : const Color(0xFF004C4C))
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSwitchTile(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    bool value,
    ValueChanged<bool>? onChanged, {
    bool isLoading = false,
  }) {
    final ValueChanged<bool>? effectiveOnChanged = isLoading ? null : onChanged;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: effectiveOnChanged == null
            ? null
            : () => effectiveOnChanged(!value),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: _buildSoftIcon(context, icon, color),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
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
                activeColor: const Color(0xFF004C4C),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumNavTile(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _buildAnimatedTileContainer(
      context: context,
      onTap: onTap ?? () {},
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: _buildSoftIcon(context, icon, color),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 24,
            ),
      ),
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

  Widget _buildCustomDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.1),
      indent: 70,
      endIndent: 20,
    );
  }

  Widget _buildBrandFooter(BuildContext context) {
    return Column(
      children: [
        Text(
          'WORKSMART',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          'CAMBODIA EDITION',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }
}
