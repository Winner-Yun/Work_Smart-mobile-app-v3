import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart'; // Added AppStrings
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/auth/tutorail_screens/tutorial_content.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _tutorialData = [
    {
      'image': AppImg.robotLove,
      'title': "tutorial_title_1",
      'subtitle': "tutorial_subtitle_1",
      'isFirst': true,
    },
    {
      'image': AppImg.secondScreen,
      'title': "tutorial_title_2",
      'subtitle': "tutorial_subtitle_2",
      'isFirst': false,
    },
    {
      'image': AppImg.thirdScreen,
      'title': "tutorial_title_3",
      'subtitle': "tutorial_subtitle_3",
      'isFirst': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScrollTimer();
  }

  void _startAutoScrollTimer() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentPage < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _completeTutorial();
    }
  }

  Future<void> _completeTutorial() async {
    final dbHelper = DatabaseHelper();
    await dbHelper.saveConfig('tutorial_seen', 'true');
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoute.authScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeTutorial,
                  child: Text(
                    AppStrings.tr('skip'), // "រំលង"
                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _tutorialData.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _timer?.cancel();
                    _startAutoScrollTimer();
                  },
                  itemBuilder: (context, index) {
                    final data = _tutorialData[index];
                    // DEV NOTE: We now translate keys here before passing to Widget
                    return TutorialContent(
                      imagePath: data['image'],
                      title: AppStrings.tr(data['title']),
                      subtitle: AppStrings.tr(data['subtitle']),
                      isFirstScreen: data['isFirst'],
                    ).animate().fadeIn(delay: (200 + (index * 10)).ms);
                  },
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _onNextPressed,
                        child: Text(
                          _currentPage == 2
                              ? AppStrings.tr('start') // "ចាប់ផ្តើម"
                              : AppStrings.tr('next'), // "បន្ទាប់"
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
  }
}
