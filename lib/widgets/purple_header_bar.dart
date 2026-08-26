import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flat header bar with an optional back button, used on every pushed
/// sub-screen (Registration, Identity Verification, Transactions, Help
/// & Support, Terms & Privacy, Notification Preferences, Notifications,
/// and the generic "coming soon" placeholders). Sits directly on
/// [AppColors.pageBackground] with no color block, matching the plain
/// look used on the bottom-nav tabs (Home, My Tickets, Resale, Profile)
/// so there's one consistent header treatment across the whole app.
class PurpleHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const PurpleHeaderBar({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.pageBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: preferredSize.height,
      leading: onBack != null
          ? IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
