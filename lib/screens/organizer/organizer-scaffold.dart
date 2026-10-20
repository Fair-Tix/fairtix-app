import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../../services/access_control.dart';
import '../../services/organizer_session.dart';
import 'organizer-dashboard.dart';
import 'organizer-subscription-plan.dart';
import 'organizer-my-events.dart';
import 'organizer-analytics-sales.dart';
import 'organizer-escrow.dart';
import 'organizer-profile.dart';
import '../user/all_events_screen.dart';
import '../../widgets/notification_bell.dart';

enum OrganizerNavItem { dashboard, myEvents, analytics, escrow, profile }

/// Shared sidebar + top bar shell wrapping every internal organizer screen,
/// matching the purple sidebar layout seen across all dashboard-family
/// screens in the reference design.
///
/// Organizer identity (name/role/avatar) is read from [OrganizerSession] by
/// default so every screen reflects the actual signed-in account instead of
/// hardcoded placeholder text. Callers may still override it explicitly if
/// needed.
class OrganizerScaffold extends StatelessWidget {
  final String pageTitle;
  final OrganizerNavItem activeItem;
  final Widget body;
  final Widget? topBarTrailing;
  final String? organizerName;
  final String? organizerRole;
  final String? avatarInitial;
  final Color avatarBgColor;

  const OrganizerScaffold({
    super.key,
    required this.pageTitle,
    required this.activeItem,
    required this.body,
    this.topBarTrailing,
    this.organizerName,
    this.organizerRole,
    this.avatarInitial,
    this.avatarBgColor = AppColors.primaryPurple,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    final account = OrganizerSession.instance.account;
    final resolvedName = organizerName ?? account?.fullName ?? 'Organizer';
    final resolvedRole = organizerRole ?? 'Organizer Account';
    final resolvedInitial = avatarInitial ?? account?.avatarInitial ?? '?';

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      drawer: isWide ? null : Drawer(child: _Sidebar(activeItem: activeItem)),
      body: Row(
        children: [
          if (isWide)
            SizedBox(width: 260, child: _Sidebar(activeItem: activeItem)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  pageTitle: pageTitle,
                  isWide: isWide,
                  trailing: topBarTrailing,
                  organizerName: resolvedName,
                  organizerRole: resolvedRole,
                  avatarInitial: resolvedInitial,
                  avatarBgColor: avatarBgColor,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [const _OrganizerLockBanner(), body],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains, at the top of every organizer page, why some features are locked
/// (waiting for admin approval, subscription expired, or no plan yet). Renders
/// nothing for an approved organizer with a current subscription, so their
/// pages look exactly as before.
class _OrganizerLockBanner extends StatelessWidget {
  const _OrganizerLockBanner();

  @override
  Widget build(BuildContext context) {
    final account = OrganizerSession.instance.account;
    final message = organizerLockMessage(
      account,
      OrganizerRequirement.subscription,
    );
    if (account == null || message == null) return const SizedBox.shrink();

    final String title;
    if (!account.isApproved) {
      title = account.idVerificationStatus == 'rejected'
          ? 'Application rejected'
          : 'Waiting for admin approval';
    } else if (account.subscriptionExpired) {
      title = 'Subscription expired';
    } else {
      title = 'No active subscription';
    }
    final canFixWithPlan = account.isApproved;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5D58A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          if (canFixWithPlan) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OrganizerSubscriptionPlanScreen(),
                  ),
                );
              },
              child: Text(
                account.subscriptionExpired ? 'Renew plan' : 'Choose a plan',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String pageTitle;
  final bool isWide;
  final Widget? trailing;
  final String organizerName;
  final String organizerRole;
  final String avatarInitial;
  final Color avatarBgColor;

  const _TopBar({
    required this.pageTitle,
    required this.isWide,
    required this.trailing,
    required this.organizerName,
    required this.organizerRole,
    required this.avatarInitial,
    required this.avatarBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              pageTitle,
              style: AppTextStyles.h3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 16)],
          const NotificationBell(),
          const SizedBox(width: 8),
          if (isWide) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(organizerName, style: AppTextStyles.label),
                Text(
                  organizerRole,
                  style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarBgColor,
            child: Text(
              avatarInitial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final OrganizerNavItem activeItem;

  const _Sidebar({required this.activeItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryPurple,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: FairTixLogo(fontSize: 22),
            ),
            _NavTile(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              isActive: activeItem == OrganizerNavItem.dashboard,
              onTap: () => _navigate(context, OrganizerNavItem.dashboard),
            ),
            _NavTile(
              icon: Icons.calendar_today_outlined,
              label: 'My Events',
              isActive: activeItem == OrganizerNavItem.myEvents,
              onTap: () => _navigate(context, OrganizerNavItem.myEvents),
            ),
            // Read-only view of the same published catalogue event goers
            // see. Opened on top of the current screen (not a sidebar page),
            // so the back button returns here.
            _NavTile(
              icon: Icons.explore_outlined,
              label: 'Browse Events',
              isActive: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AllEventsScreen(readOnly: true),
                ),
              ),
            ),
            _NavTile(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              isActive: activeItem == OrganizerNavItem.analytics,
              onTap: () => _navigate(context, OrganizerNavItem.analytics),
            ),
            _NavTile(
              icon: Icons.lock_outline,
              label: 'Escrow & Payouts',
              isActive: activeItem == OrganizerNavItem.escrow,
              onTap: () => _navigate(context, OrganizerNavItem.escrow),
            ),
            _NavTile(
              icon: Icons.person_outline,
              label: 'Profile',
              isActive: activeItem == OrganizerNavItem.profile,
              onTap: () => _navigate(context, OrganizerNavItem.profile),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _NavTile(
                icon: Icons.help_outline,
                label: 'Support',
                isActive: false,
                filled: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support is coming soon.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, OrganizerNavItem item) {
    if (item == activeItem) return;
    late final Widget target;
    switch (item) {
      case OrganizerNavItem.dashboard:
        target = const OrganizerDashboardScreen();
        break;
      case OrganizerNavItem.myEvents:
        target = const OrganizerMyEventsScreen();
        break;
      case OrganizerNavItem.analytics:
        target = const OrganizerAnalyticsSalesScreen();
        break;
      case OrganizerNavItem.escrow:
        target = const OrganizerEscrowScreen();
        break;
      case OrganizerNavItem.profile:
        target = const OrganizerProfileScreen();
        break;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => target,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool filled;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isActive
            ? AppColors.sidebarActive
            : (filled
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isActive ? 1 : 0.85),
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
