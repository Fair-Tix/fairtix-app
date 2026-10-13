import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/purple_header_bar.dart';

/// Minimal "coming soon" placeholder for pushed sub-screens that aren't
/// full bottom-nav tabs (Change Password, Notification Preferences,
/// Help & Support). Unlike [ComingSoonScreen], this has a back button
/// and no bottom nav, since it's meant to be pushed on top of a tab
/// rather than replace one.
class SimplePlaceholderScreen extends StatelessWidget {
  const SimplePlaceholderScreen({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: title,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Center(
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
    );
  }
}
