import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/face/face_attendance_verifier.dart';

class FacePoseHintStrip extends StatelessWidget {
  const FacePoseHintStrip({
    super.key,
    this.activeStep,
    this.completedSteps = const <LivenessAction>{},
  });

  final LivenessAction? activeStep;
  final Set<LivenessAction> completedSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.tr('face_pose_hint_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.tr('face_pose_hint_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 11,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPoseItem(
                action: LivenessAction.turnLeft,
                imagePath: AppImg.lookToLeft,
                label: AppStrings.tr('face_pose_left'),
              ),
              const SizedBox(width: 8),
              _buildPoseItem(
                action: LivenessAction.turnRight,
                imagePath: AppImg.lookToRight,
                label: AppStrings.tr('face_pose_right'),
              ),
              const SizedBox(width: 8),
              _buildPoseItem(
                action: LivenessAction.blink,
                imagePath: AppImg.closeOpenEye,
                label: AppStrings.tr('face_pose_blink_eyes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPoseItem({
    required LivenessAction action,
    required String imagePath,
    required String label,
  }) {
    final bool isActive = activeStep == action;
    final bool isCompleted = completedSteps.contains(action);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.yellow.withOpacity(0.28)
                : isCompleted
                ? Colors.greenAccent.withOpacity(0.18)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? Colors.yellow.withOpacity(0.95)
                  : isCompleted
                  ? Colors.greenAccent.withOpacity(0.95)
                  : Colors.white.withOpacity(0.14),
            ),
          ),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 54,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive
                  ? Colors.yellow.withOpacity(0.95)
                  : isCompleted
                  ? Colors.greenAccent.withOpacity(0.95)
                  : Colors.white.withOpacity(0.78),
              fontSize: 9.5,
              height: 1.05,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
