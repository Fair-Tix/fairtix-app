import 'package:flutter/material.dart';

import '../../services/access_control.dart';
import '../../services/organizer_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/top_glow_background.dart';
import 'organizer-analytics-sales.dart';
import 'organizer-dashboard.dart';
import 'organizer-escrow.dart';
import 'organizer-my-events.dart';
import 'organizer-profile.dart';
import 'organizer-subscription-plan.dart';

enum OrganizerNavItem { dashboard, myEvents, analytics, escrow, profile }

/// Shared shell for every internal organizer screen (Mahilum design): logo on
/// the left, a pill navigation in the middle, the notification bell and the
/// account avatar on the right, and the amber "locked" banner above the page.
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
    final wide = width >= 900;
    final pad = width >= 1000 ? 32.0 : 20.0;

    final account = OrganizerSession.instance.account;
    final initial = avatarInitial ?? account?.avatarInitial ?? '?';

    return Scaffold(
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
  }
  Navigator.pushReplacement(context, organizerFadeRoute<void>(target));
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

    return SizedBox(
      height: 48,
      child: Row(
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
          Expanded(
            child: wide
                ? Center(child: _NavPill(activeItem: activeItem))
                : const SizedBox.shrink(),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 16)],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            alignment: Alignment.center,
            child: NotificationBell(
              color: p.accentLabel,
              size: 20,
              badgeBorderColor: p.surface,
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: profileActive
                  ? null
                  : () => _goTo(context, OrganizerNavItem.profile),
              child: Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: profileActive ? p.accentLabel : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarColor,
                    gradient: avatarColor == null
                        ? FairTixPalette.buttonGradient
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatarInitial,
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
              height: 1.2,
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
