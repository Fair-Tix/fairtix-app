import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small dot-progress indicator used across the multi-step verification
/// flow (Identity Verification, Selfie).
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.activeColor = AppColors.accentPurple,
    this.inactiveColor = AppColors.pendingDot,
  });

  final int totalSteps;
  final int currentStep; // 0-indexed
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final bool isActive = index <= currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }
}
