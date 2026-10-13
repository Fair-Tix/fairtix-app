import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../services/organizer_session.dart';
import 'organizer-dashboard.dart';
import 'organizer-my-events.dart';
import 'organizer-analytics-sales.dart';
import 'organizer-profile.dart';

enum OrganizerNavItem { dashboard, myEvents, analytics, profile }

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
    final resolvedName = organizerName ?? account?.organizationName ?? 'Organizer';
    final resolvedRole = organizerRole ?? 'Organizer Account';
    final resolvedInitial = avatarInitial ?? account?.avatarInitial ?? '?';

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      drawer: isWide
          ? null
          : Drawer(
              child: _Sidebar(activeItem: activeItem),
            ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 260,
              child: _Sidebar(activeItem: activeItem),
            ),
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
                    child: body,
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
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
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
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 16),
          ],
          if (isWide) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(organizerName, style: AppTextStyles.label),
                Text(organizerRole, style: AppTextStyles.bodyGray.copyWith(fontSize: 12)),
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
            _NavTile(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              isActive: activeItem == OrganizerNavItem.analytics,
              onTap: () => _navigate(context, OrganizerNavItem.analytics),
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
                    const SnackBar(
                      content: Text('Support is coming soon.'),
                    ),
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
            : (filled ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
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