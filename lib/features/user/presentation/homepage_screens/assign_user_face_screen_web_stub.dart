import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';

class RegisterFaceScanScreen extends StatelessWidget {
  final Map<String, dynamic>? loginData;

  const RegisterFaceScanScreen({super.key, this.loginData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('face_training_title'))),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Face registration is not supported on web.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
