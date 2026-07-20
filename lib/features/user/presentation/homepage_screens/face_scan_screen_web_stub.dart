import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';

class FaceScanScreen extends StatelessWidget {
  final Map<String, dynamic>? loginData;

  const FaceScanScreen({super.key, this.loginData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('face_scan_title'))),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Face scan is not supported on web.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
