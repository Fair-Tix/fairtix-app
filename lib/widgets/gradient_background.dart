import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wraps a screen with the purple gradient + soft blurred "blob" accents
/// used across the FairTix onboarding/auth screens.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child, this.gradient = AppGradients.background});

  final Widget child;

  /// Defaults to the general onboarding/auth gradient. Pass
  /// [AppGradients.confirmation] for "result" screens (Ticket Confirmed,
  /// Account Activated, Ticket Sold, Ticket Listed for Resale, etc.).
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          _blob(top: -60, left: -40, size: 220),
          _blob(top: 120, right: -80, size: 260),
          _blob(bottom: -60, left: -60, size: 240),
          SafeArea(child: child),
        ],
      ),
    );
  }

  Widget _blob({double? top, double? left, double? right, double? bottom, required double size}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.blobLight,
          ),
        ),
      ),
    );
  }
}
