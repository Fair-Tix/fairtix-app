import 'package:flutter/material.dart';

import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

/// Minimal placeholder for the Resale and Profile tabs so the bottom nav
/// has somewhere to go for every tab while those modules are still being
/// designed.
/// TODO: replace with the real Resale marketplace / Profile screens.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.navIndex});

  final String title;
  final IconData icon;
  final int navIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48, color: AppColors.accentPurple.withValues(alpha: 0.35)),
                    const SizedBox(height: 14),
                    Text(title, style: AppTextStyles.sectionHeading),
                    const SizedBox(height: 6),
                    const Text('Coming soon.', style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              currentIndex: navIndex,
              onTap: (index) {
                if (index == navIndex) return;
                navigateToTab(context, index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
