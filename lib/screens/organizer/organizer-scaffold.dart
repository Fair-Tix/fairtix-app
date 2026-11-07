import 'package:flutter/material.dart';

import '../../services/access_control.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import '../../services/support_contact.dart';
import '../../theme/fairtix_palette.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/organizer_top_menus.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/theme_mode_switch.dart';
import '../../widgets/top_glow_background.dart';
import '../../widgets/terms_acceptance_gate.dart';
import 'organizer-analytics-sales.dart';
import 'organizer-dashboard.dart';
import 'organizer-escrow.dart';
import 'organizer-help.dart';
import 'organizer-my-events.dart';
import 'organizer-profile.dart';
import 'organizer-settings.dart';
import 'organizer-splash.dart';
import 'organizer-subscription-plan.dart';
import 'organizer-subscription.dart';

/// How much smaller organizer page text is drawn (0.9 = 10% smaller).
const double organizerTextShrink = 0.9;

enum OrganizerNavItem {
  dashboard,
  myEvents,
  analytics,
  escrow,
  profile,
  subscription,
  settings,
  help,
}

/// Shared shell for every internal organizer screen (Mahilum design): logo on
/// the left, a pill navigation in the middle, the notification bell and the
/// account avatar on the right (each opens a dropdown), and the amber "locked"
/// banner above the page.
///
/// Organizer identity (avatar initial) is read from [OrganizerSession] by
/// default. [pageTitle], [organizerName] and [organizerRole] are kept so the
/// existing screens compile unchanged, but the new design does not show them.
class OrganizerScaffold extends StatelessWidget {
  final String pageTitle;
  final OrganizerNavItem activeItem;
  final Widget body;
  final Widget? topBarTrailing;
  final String? organizerName;
  final String? organizerRole;
  final String? avatarInitial;
  final Color? avatarBgColor;

  const OrganizerScaffold({
    super.key,
    required this.pageTitle,
    required this.activeItem,
    required this.body,
    this.topBarTrailing,
    this.organizerName,
    this.organizerRole,
    this.avatarInitial,
    this.avatarBgColor,
  });

  static const double _maxContentWidth = 1600;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 1100;
    final pad = width >= 1000 ? 32.0 : 20.0;

    final account = OrganizerSession.instance.account;
    final initial = avatarInitial ?? account?.avatarInitial ?? '?';

    // Organizer pages are drawn a little smaller than the raw text sizes (the
    // user's own font setting is kept). Tune [organizerTextShrink] (1.0 = off).
    final media = MediaQuery.of(context);
    final userScale = media.textScaler.scale(14) / 14;

    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(userScale * organizerTextShrink),
      ),
      child: TermsAcceptanceGate(child: Scaffold(
      backgroundColor: p.background,
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
                        wide: wide,
                        activeItem: activeItem,
                        trailing: topBarTrailing,
                        avatarInitial: initial,
                        avatarColor: avatarBgColor,
                      ),
                    ),
                  ),
                ),
                if (!wide)
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _NavPill(activeItem: activeItem),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PageEntrance(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [const _OrganizerLockBanner(), body],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      )),
      ),
    );
  }
}

/// Fades the page content in and lifts it a few pixels the first time a
/// screen opens, so every internal organizer page settles in the same way.
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

void _goTo(BuildContext context, OrganizerNavItem item) {
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
    case OrganizerNavItem.subscription:
      target = const OrganizerSubscriptionScreen();
      break;
    case OrganizerNavItem.settings:
      target = const OrganizerSettingsScreen();
      break;
    case OrganizerNavItem.help:
      target = const OrganizerHelpScreen();
      break;
  }
  Navigator.pushReplacement(context, organizerFadeRoute<void>(target));
}

/// Confirms, then signs the organizer out and returns to the splash screen.
/// Shared by the profile dropdown and the Profile page's Log Out button.
void confirmOrganizerLogOut(BuildContext context) {
  final p = FairTixPalette.of(context);
  showDialog(
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
        'You will need to log in again to access your organizer dashboard.',
        style: orgText(p, size: 14, color: p.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancel',
            style: orgText(p, size: 14, weight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            OrganizerAuthService.instance.logout();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have been logged out.')),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const OrganizerSplashScreen()),
              (route) => false,
            );
          },
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
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.wide,
    required this.activeItem,
    required this.trailing,
    required this.avatarInitial,
    required this.avatarColor,
  });

  final bool wide;
  final OrganizerNavItem activeItem;
  final Widget? trailing;
  final String avatarInitial;
  final Color? avatarColor;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final profileActive = activeItem == OrganizerNavItem.profile;
    // The profile menu's pages all highlight the avatar.
    final accountActive = const {
      OrganizerNavItem.profile,
      OrganizerNavItem.subscription,
      OrganizerNavItem.settings,
      OrganizerNavItem.help,
    }.contains(activeItem);

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The pill is centered on the bar itself, so it stays put no matter
          // how many buttons each page puts on the right.
          if (wide) Center(child: _NavPill(activeItem: activeItem)),
          Row(
        children: [
          const FairTixMark(width: 40),
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
          const Spacer(),
          if (trailing != null) ...[trailing!, const SizedBox(width: 12)],
          const ThemeModeSwitch(),
          const SizedBox(width: 12),
          const OrganizerBellButton(),
          const SizedBox(width: 12),
          OrganizerAvatarButton(
            initial: avatarInitial,
            color: avatarColor,
            highlighted: accountActive,
            actions: OrganizerProfileMenuActions(
              onProfile: () {
                if (!profileActive) _goTo(context, OrganizerNavItem.profile);
              },
              onMyEvents: () {
                if (activeItem != OrganizerNavItem.myEvents) {
                  _goTo(context, OrganizerNavItem.myEvents);
                }
              },
              // Opens the "Choose your plan" screen (Mahilum design) on top of
              // the current page, so its Back button returns here.
              onSubscription: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OrganizerSubscriptionPlanScreen(),
                  ),
                );
              },
              onSettings: () {
                if (activeItem != OrganizerNavItem.settings) {
                  _goTo(context, OrganizerNavItem.settings);
                }
              },
              // Hidden from the menu until FairTix has a contact address.
              onHelp: FairTixSupport.isAvailable
                  ? () {
                      if (activeItem != OrganizerNavItem.help) {
                        _goTo(context, OrganizerNavItem.help);
                      }
                    }
                  : null,
              onSignOut: () => confirmOrganizerLogOut(context),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.activeItem});

  final OrganizerNavItem activeItem;

  static const _items = <(OrganizerNavItem, String)>[
    (OrganizerNavItem.dashboard, 'Dashboard'),
    (OrganizerNavItem.myEvents, 'My Events'),
    (OrganizerNavItem.analytics, 'Analytics'),
    (OrganizerNavItem.escrow, 'Escrow & Payouts'),
  ];

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
          for (final (item, label) in _items)
            _NavPillItem(
              label: label,
              active: item == activeItem,
              onTap: () {
                if (item != activeItem) _goTo(context, item);
              },
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
    final radius = BorderRadius.circular(999);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: radius,
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
            style: orgText(
              p,
              size: 15,
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
// Lock banner
// ---------------------------------------------------------------------------

/// Explains, at the top of every organizer page, why some features are locked
/// (waiting for admin approval, subscription expired, or no plan yet). Renders
/// nothing for an approved organizer with a current subscription.
class _OrganizerLockBanner extends StatelessWidget {
  const _OrganizerLockBanner();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
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
    // On narrow screens the action link drops under the message instead of
    // squeezing the text into a thin column beside it.
    final narrow = MediaQuery.of(context).size.width < 600;
    final linkLabel =
        account.subscriptionExpired ? 'Renew plan' : 'Choose a plan';
    void openPlans() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OrganizerSubscriptionPlanScreen(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: p.warningSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, color: p.warning, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: orgText(p, size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: orgText(
                    p,
                    size: 14,
                    color: p.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (narrow && canFixWithPlan) ...[
                  const SizedBox(height: 8),
                  OrganizerTextLink(
                    label: linkLabel,
                    size: 15,
                    onTap: openPlans,
                  ),
                ],
              ],
            ),
          ),
          if (canFixWithPlan && !narrow) ...[
            const SizedBox(width: 16),
            OrganizerTextLink(
              label: linkLabel,
              size: 15,
              onTap: openPlans,
            ),
          ],
        ],
      ),
    );
  }
}
