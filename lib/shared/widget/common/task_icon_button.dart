import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';

/// Task icon shown in the app bar of every main tab, opening [TaskScreen].
class TaskIconButton extends StatelessWidget {
  final Map<String, dynamic>? loginData;
  final Color? iconColor;

  const TaskIconButton({super.key, this.loginData, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.tr('task_menu'),
      onPressed: () => Navigator.pushNamed(
        context,
        AppRoute.taskScreen,
        arguments: loginData,
      ),
      icon: Icon(Icons.task_outlined),
    );
  }
}
