import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedFaqIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.textLight,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.tr('help_support_title'),
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(AppStrings.tr('contact_us'), context),
            const SizedBox(height: 15),
            _buildSupportCard(
              context,
              icon: Icons.headset_mic_rounded,
              title: AppStrings.tr('customer_service'),
              subtitle: AppStrings.tr('quick_response'),
              color: Colors.blue,
              onTap: () {},
            ),
            const SizedBox(height: 15),
            _buildSupportCard(
              context,
              icon: Icons.mail_rounded,
              title: AppStrings.tr('send_email'),
              subtitle: 'support@worksmart.kh',
              color: Colors.orange,
              onTap: () {},
            ),
            const SizedBox(height: 30),
            _buildSectionHeader(AppStrings.tr('faq_title'), context),
            const SizedBox(height: 15),
            _buildFAQTile(
              question: AppStrings.tr('faq_change_pass'),
              answer: AppStrings.tr('faq_change_pass_answer'),
              index: 0,
              context: context,
            ),
            _buildFAQTile(
              question: AppStrings.tr('faq_connect_tele'),
              answer: AppStrings.tr('faq_connect_tele_answer'),
              index: 1,
              context: context,
            ),
            _buildFAQTile(
              question: AppStrings.tr('faq_login_issue'),
              answer: AppStrings.tr('faq_login_issue_answer'),
              index: 2,
              context: context,
            ),
            const SizedBox(height: 40),
            _buildVersionInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildSupportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildFAQTile({
    required String question,
    required String answer,
    required int index,
    required BuildContext context,
  }) {
    final bool isExpanded = _expandedFaqIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          setState(() {
            _expandedFaqIndex = isExpanded ? null : index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(question, style: const TextStyle(fontSize: 14)),
                  ),
                  AnimatedRotation(
                    duration: 220.ms,
                    turns: isExpanded ? 0.125 : 0,
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: 220.ms,
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    answer,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? AppImg.appIconDark
                : AppImg.appIcon,
            height: 40,
            errorBuilder: (c, e, s) => Icon(
              Icons.business_center,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'WorkSmart Mobile App',
            style: TextStyle(
              color: AppColors.textGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Version 1.0.0',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}
