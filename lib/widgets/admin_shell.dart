import 'package:flutter/material.dart';

import '../screens/admin/admin-accounts.dart';
import '../screens/admin/admin-dashboard.dart';
import '../screens/admin/admin-events-tickets.dart';
import '../screens/admin/admin-fraud-alerts.dart';
import '../screens/admin/admin-login.dart';
import '../screens/admin/admin-organizer-applications.dart';
import '../screens/admin/admin-platform-settings.dart';
import '../screens/admin/admin-profile.dart';
import '../screens/admin/admin-resale-monitoring.dart';
import '../screens/admin/admin-revenue-reports.dart';
import '../screens/admin/admin-user-registrations.dart';
import 'organizer_top_menus.dart';
import '../screens/admin/admin-route.dart';
import '../theme/fairtix_palette.dart';
import '../theme/theme_controller.dart';
import 'fairtix_mark.dart';
import 'organizer_ui.dart';
import 'theme_mode_switch.dart';
import 'top_glow_background.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_session.dart';

/// The sections in the admin navigation, in display order.
enum AdminNavItem {
  dashboard(Icons.grid_view_rounded, 'Dashboard'),
  organizerApplications(Icons.business_outlined, 'Organizer Applications'),
  userRegistrations(Icons.how_to_reg_outlined, 'User Registrations'),
  accounts(Icons.people_outline, 'Accounts'),
  eventsTickets(Icons.calendar_today_outlined, 'Events & Tickets'),
  resaleMonitoring(Icons.swap_vert_rounded, 'Resale Monitoring'),
  fraudAlerts(Icons.shield_outlined, 'Fraud Alerts'),
  revenueReports(Icons.bar_chart_rounded, 'Revenue & Reports'),
  platformSettings(Icons.settings_outlined, 'Platform Settings'),
  profile(Icons.person_outline, 'Profile');

  const AdminNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

Widget _pageFor(AdminNavItem item) => switch (item) {
  AdminNavItem.dashboard => const AdminDashboardScreen(),
  AdminNavItem.organizerApplications =>
    const AdminOrganizerApplicationsScreen(),
  AdminNavItem.userRegistrations => const AdminUserRegistrationsScreen(),
  AdminNavItem.accounts => const AdminAccountsScreen(),
  AdminNavItem.eventsTickets => const AdminEventsTicketsScreen(),
  AdminNavItem.resaleMonitoring => const AdminResaleMonitoringScreen(),
  AdminNavItem.fraudAlerts => const AdminFraudAlertsScreen(),
  AdminNavItem.revenueReports => const AdminRevenueReportsScreen(),
  AdminNavItem.platformSettings => const AdminPlatformSettingsScreen(),
  AdminNavItem.profile => const AdminProfileScreen(),
};

void _goTo(BuildContext context, AdminNavItem item, AdminNavItem active) {
  if (item == active) return;
  adminPushReplacement(context, _pageFor(item));
}

Future<void> _logoutAdmin(BuildContext context) async {
  final p = FairTixPalette.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      title: Text(
        'Log Out?',
        style: orgText(p, size: 18, weight: FontWeight.w800),
      ),
      content: Text(
        'Are you sure you want to log out?',
        style: orgText(p, size: 14, color: p.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: orgText(p, size: 14, weight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Log Out',
            style: orgText(
              p,
              size: 14,
              weight: FontWeight.w700,
              color: p.danger,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  AdminAuthService.instance.logout();
  adminPushAndRemoveUntil(context, const AdminLoginScreen());
}

String _adminNavLabel(AdminNavItem item) => switch (item) {
  AdminNavItem.organizerApplications => 'Applications',
  AdminNavItem.userRegistrations => 'Registrations',
  AdminNavItem.eventsTickets => 'Events',
  AdminNavItem.resaleMonitoring => 'Resale',
  AdminNavItem.fraudAlerts => 'Alerts',
  AdminNavItem.revenueReports => 'Reports',
  AdminNavItem.platformSettings => 'Settings',
  _ => item.label,
};

/// The frame every admin screen shares, styled like the organizer shell: logo
/// on the left, a centered pill navigation, the theme switch, notification
/// bell and account avatar on the right. Windows narrower than
/// [_pillBreakpoint] get a menu button that opens a navigation drawer instead
/// of the pill.
///
/// Logging out here calls [AdminAuthService.logout], which also signs the
/// Supabase session out.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.active,
    required this.title,
    required this.body,
  });

  final AdminNavItem active;
  final String title;
  final Widget body;

  /// Below this width the 8-item pill no longer fits, so a drawer is used.
  static const double _pillBreakpoint = 1280;
  static const double _maxContentWidth = 1600;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final palette = FairTixPalette.of(context);
    final pill = width >= _pillBreakpoint;
    final pad = width >= 1000 ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: palette.background,
      drawer: pill ? null : _AdminDrawer(active: active),
      body: Stack(
        children: [
          const TopGlowBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                      child: _TopBar(
                        title: title,
                        width: width,
                        pill: pill,
                        active: active,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxContentWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
                          child: _PageEntrance(child: body),
                        ),
                      ),
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

/// Fades the page content in and lifts it a few pixels the first time a
/// screen opens, matching the organizer pages.
class _PageEntrance extends StatelessWidget {
  const _PageEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.width,
    required this.pill,
    required this.active,
  });

  final String title;
  final double width;
  final bool pill;
  final AdminNavItem active;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final phone = width < 700;

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered on the bar itself so it stays put regardless of what is
          // on the right.
          if (pill) Center(child: _NavPill(active: active)),
          Row(
            children: [
              if (!pill) ...[
                Builder(
                  builder: (ctx) => _RoundIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'Menu',
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              _AdminLogo(compact: phone),
              if (pill)
                const Spacer()
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: phone ? TextAlign.start : TextAlign.center,
                      style: orgText(p, size: 16, weight: FontWeight.w700),
                    ),
                  ),
                ),
              if (!phone) ...[const ThemeModeSwitch(), const SizedBox(width: 12)],
              const OrganizerBellButton(),
              const SizedBox(width: 12),
              _AccountMenu(active: active, showThemeToggle: phone),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surface,
              border: Border.all(color: p.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: p.accentLabel),
          ),
        ),
      ),
    );
  }
}

class _AccountMenu extends StatefulWidget {
  const _AccountMenu({required this.active, required this.showThemeToggle});

  final AdminNavItem active;

  /// On phones the theme switch leaves the top bar, so it moves in here.
  final bool showThemeToggle;

  @override
  State<_AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<_AccountMenu> {
  bool _open = false;

  Future<void> _toggle() async {
    setState(() => _open = true);
    await showTopMenuDropdown(
      context,
      width: 340,
      builder: (ctx, p, maxHeight) {
        void run(VoidCallback action) {
          Navigator.of(ctx).pop();
          action();
        }

        return _AdminProfilePanel(
          p: p,
          maxHeight: maxHeight,
          showThemeToggle: widget.showThemeToggle,
          onProfile: () => run(
            () => _goTo(context, AdminNavItem.profile, widget.active),
          ),
          onSettings: () => run(
            () => _goTo(context, AdminNavItem.platformSettings, widget.active),
          ),
          onToggleTheme: () => run(ThemeController.instance.toggle),
          onSignOut: () => run(() => _logoutAdmin(context)),
        );
      },
    );
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final email = AdminSession.instance.currentEmail ?? 'admin';
    final ring =
        _open ||
        widget.active == AdminNavItem.profile ||
        widget.active == AdminNavItem.platformSettings;

    return Tooltip(
      message: 'Account menu',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: FairTixPalette.buttonGradient,
              border: ring ? Border.all(color: p.accentLabel, width: 2) : null,
              boxShadow: [
                BoxShadow(
                  color: p.primary.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              email.isEmpty ? 'A' : email[0].toUpperCase(),
              style: orgText(
                p,
                size: 16,
                weight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Organizer-style profile panel: a header card with the signed-in admin,
/// then Profile, Settings, (phones only) the theme toggle and Sign out.
class _AdminProfilePanel extends StatelessWidget {
  const _AdminProfilePanel({
    required this.p,
    required this.maxHeight,
    required this.showThemeToggle,
    required this.onProfile,
    required this.onSettings,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final FairTixPalette p;
  final double maxHeight;
  final bool showThemeToggle;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final email = AdminSession.instance.currentEmail ?? 'admin';

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: topMenuPanelDecoration(p),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: p.isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrator',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: orgText(
                            p,
                            size: 15,
                            weight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: orgText(
                            p,
                            size: 13,
                            color: p.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: p.primary.withValues(
                              alpha: p.isDark ? 0.24 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 12,
                                color: p.accentLabel,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Admin',
                                style: orgText(
                                  p,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: p.accentLabel,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FairTixPalette.buttonGradient,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      email.isEmpty ? 'A' : email[0].toUpperCase(),
                      style: orgText(
                        p,
                        size: 22,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TopMenuItem(
              p: p,
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Account information and password',
              onTap: onProfile,
            ),
            TopMenuItem(
              p: p,
              icon: Icons.tune_rounded,
              title: 'Settings',
              subtitle: 'Fees, purchase limits and resale rules',
              onTap: onSettings,
            ),
            if (showThemeToggle)
              TopMenuItem(
                p: p,
                icon: p.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                title: p.isDark ? 'Light mode' : 'Dark mode',
                onTap: onToggleTheme,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Divider(height: 1, color: p.border),
            ),
            TopMenuItem(
              p: p,
              icon: Icons.logout_rounded,
              title: 'Sign out',
              danger: true,
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo
// ---------------------------------------------------------------------------

class _AdminLogo extends StatelessWidget {
  const _AdminLogo({this.compact = false});

  /// Mark only (phones).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FairTixMark(width: compact ? 34 : 40),
        if (!compact) ...[
          const SizedBox(width: 8),
          Text(
            'FairTix',
            style: orgText(
              p,
              size: 24,
              weight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: p.isDark ? 0.24 : 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'ADMIN',
              style: orgText(
                p,
                size: 10,
                weight: FontWeight.w800,
                color: p.accentLabel,
                letterSpacing: 0.8,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pill navigation (wide windows)
// ---------------------------------------------------------------------------

class _NavPill extends StatelessWidget {
  const _NavPill({required this.active});

  final AdminNavItem active;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in AdminNavItem.values.where(
            (item) =>
                item != AdminNavItem.profile &&
                item != AdminNavItem.platformSettings,
          ))
            _NavPillItem(
              label: _adminNavLabel(item),
              active: item == active,
              onTap: () => _goTo(context, item, active),
            ),
        ],
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  const _NavPillItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? FairTixPalette.buttonGradient : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: orgText(
              p,
              size: 13,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : p.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawer (narrow windows)
// ---------------------------------------------------------------------------

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.active});

  final AdminNavItem active;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final email = AdminSession.instance.currentEmail ?? 'admin';

    return Drawer(
      backgroundColor: p.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 16, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _AdminLogo(),
              ),
            ),
            Divider(height: 1, color: p.border),
            // Scrolls on short screens so the list can never overflow; the
            // account footer stays pinned below.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                children: [
                  for (final item in AdminNavItem.values)
                    _DrawerItem(
                      icon: item.icon,
                      label: item.label,
                      selected: item == active,
                      onTap: () => _goTo(context, item, active),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.isDark ? 'Dark mode' : 'Light mode',
                      style: orgText(
                        p,
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                  const ThemeModeSwitch(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: p.progressTrack,
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: orgText(p, size: 14, weight: FontWeight.w700),
                        ),
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: orgText(
                            p,
                            size: 12,
                            color: p.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _logoutAdmin(context),
                    icon: Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: p.textSecondary,
                    ),
                    tooltip: 'Log out',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: selected ? FairTixPalette.buttonGradient : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : p.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: orgText(
                        p,
                        size: 14,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : p.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
