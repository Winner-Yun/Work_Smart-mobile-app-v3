import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic>? loginData;

  const ProfileScreen({super.key, this.loginData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('profile_menu'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This feature is currently not available on web.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
