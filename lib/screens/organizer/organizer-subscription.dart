import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import '../../models/subscription_plan.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import '../../services/subscription_plan_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_account_ui.dart';
import '../../widgets/organizer_ui.dart';
import 'app_colors.dart' show formatFriendlyDate;
import 'organizer-scaffold.dart';
import 'organizer-subscription-plan.dart';

/// Organizer Subscription: the plan the organizer is on, what it costs, whether
/// it is active, when the current period ends, and its limits.
///
/// Everything is read from the organizer's real subscription: the status badge
/// says Active, Expired or No plan from the account itself, and the price and
/// limits come from the plan row the admin saved in Platform Settings. Paying
/// or switching plans happens on [OrganizerSubscriptionPlanScreen].
class OrganizerSubscriptionScreen extends StatefulWidget {
  const OrganizerSubscriptionScreen({super.key});

  @override
  State<OrganizerSubscriptionScreen> createState() =>
      _OrganizerSubscriptionScreenState();
}

class _OrganizerSubscriptionScreenState
    extends State<OrganizerSubscriptionScreen> {
  SubscriptionPlan? _plan;
  bool _planFailed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Re-reads the account (a payment may have just gone through) and then the
  /// plan's price and limits.
  Future<void> _refresh() async {
    await OrganizerAuthService.instance.refreshAccount();
    if (mounted) setState(() {});
    await _loadPlan();
  }

  Future<void> _loadPlan() async {
    final name = OrganizerSession.instance.account?.subscriptionPlan;
    if (name == null) {
      if (mounted) {
        setState(() {
          _plan = null;
          _planFailed = false;
        });
      }
      return;
    }
    try {
      final plan = await SubscriptionPlanService.instance.fetchPlanByName(name);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _planFailed = plan == null;
      });
    } on SubscriptionPlanException {
      if (mounted) setState(() => _planFailed = true);
    } catch (_) {
      if (mounted) setState(() => _planFailed = true);
    }
  }

  Future<void> _openPlans() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganizerSubscriptionPlanScreen(),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final account = OrganizerSession.instance.account;

    return OrganizerScaffold(
      pageTitle: 'Subscription',
      activeItem: OrganizerNavItem.subscription,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrganizerPageHeader(
            title: 'Subscription',
            subtitle: 'Your plan, billing period and limits.',
          ),
          const SizedBox(height: 24),
          _hero(p, account),
          const SizedBox(height: 24),
          _limitsCard(p, account),
        ],
      ),
    );
  }

  // --- hero ----------------------------------------------------------------

  Widget _hero(FairTixPalette p, OrganizerAccount? account) {
    final plan = account?.subscriptionPlan;
    final active = account?.hasActiveSubscription ?? false;
    final expired = account?.subscriptionExpired ?? false;

    final String title = active
        ? '$plan plan'
        : expired
        ? 'Subscription expired'
        : 'No active plan';

    final String? priceLine = active
        ? (_plan == null ? null : '${_plan!.priceLabel} / month')
        : null;

    final String periodLine;
    if (active) {
      final ends = account?.subscriptionRenewsAt;
      periodLine = ends == null
          ? 'Your plan is active.'
          : 'Current period ends ${formatFriendlyDate(ends)}';
    } else if (expired) {
      final ended = account?.subscriptionExpiredAt;
      periodLine = ended == null
          ? 'Your plan has expired. Renew to unlock event features again.'
          : 'Expired on ${formatFriendlyDate(ended)}. Renew to unlock event '
                'features again.';
    } else {
      periodLine = 'Choose a plan to start creating events and selling tickets.';
    }

    final String badge = active ? 'Active' : (expired ? 'Expired' : 'No plan');
    final String action = active
        ? 'Manage plan'
        : (expired ? 'Renew plan' : 'Choose a plan');

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.primary.withValues(alpha: 0.5)),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF3F1A8F), Color(0xFF5B2BC2), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: p.isDark ? 0.30 : 0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current plan',
                      style: orgText(p, size: 15, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: orgText(
                        p,
                        size: 30,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    if (priceLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        priceLine,
                        style: orgText(
                          p,
                          size: 18,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      periodLine,
                      style: orgText(p, size: 15, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeroBadge(label: badge, active: active, expired: expired),
            ],
          ),
          const SizedBox(height: 26),
          _WhiteButton(label: action, onTap: _openPlans),
        ],
      ),
    );
  }

  // --- limits --------------------------------------------------------------

  Widget _limitsCard(FairTixPalette p, OrganizerAccount? account) {
    final active = account?.hasActiveSubscription ?? false;
    final plan = _plan;

    Widget body;
    if (!active) {
      body = Text(
        'Plan limits appear here once you have an active plan.',
        style: orgText(p, size: 14.5, color: p.textSecondary, height: 1.5),
      );
    } else if (plan == null && !_planFailed) {
      // The plan row is still loading: rows shaped like the limits list.
      body = const _LimitsSkeleton();
    } else if (plan == null) {
      final fee = account?.subscriptionFeeRate;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fee != null) _LimitRow(label: 'Platform fee', value: '${_pct(fee)}%'),
          Padding(
            padding: EdgeInsets.only(top: fee != null ? 12 : 0),
            child: Text(
              'Plan details couldn\u2019t be loaded right now.',
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LimitRow(
            label: 'Events per month',
            value: plan.maxEventsPerMonth == null
                ? 'Unlimited'
                : '${plan.maxEventsPerMonth}',
            first: true,
          ),
          _LimitRow(
            label: 'Tickets per day',
            value: plan.maxTicketsPerDay == null
                ? 'Unlimited'
                : _n(plan.maxTicketsPerDay!),
          ),
          _LimitRow(
            label: 'Days per multi-day event',
            value: plan.maxMultiDayDays == null
                ? 'Unlimited'
                : '${plan.maxMultiDayDays}',
          ),
          _LimitRow(label: 'Platform fee', value: '${_pct(plan.feeRate)}%'),
          _LimitRow(
            label: 'Report export',
            value: plan.canExport ? 'Included' : 'Not included',
          ),
          if (plan.benefits.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Included in your plan',
              style: orgText(p, size: 14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final b in plan.benefits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: p.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b,
                        style: orgText(
                          p,
                          size: 14.5,
                          color: p.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      );
    }

    return OrganizerSectionCard(title: 'Plan limits', child: body);
  }

  static String _n(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  static String _pct(double fraction) {
    final v = fraction * 100;
    return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  }
}

/// Placeholder for the plan limits while the plan row loads: five rows in the
/// shape of [_LimitRow] (label left, value right, divider between).
class _LimitsSkeleton extends StatelessWidget {
  const _LimitsSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    Widget row(double labelWidth, {bool first = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 15.5),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FtSkeletonBox(width: labelWidth, height: 15),
              ),
            ),
            const FtSkeletonBox(width: 70, height: 15),
          ],
        ),
      );
    }

    return FtShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(130, first: true),
          row(110),
          row(170),
          row(100),
          row(120),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.active,
    required this.expired,
  });

  final String label;
  final bool active;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final dot = active
        ? const Color(0xFF4ADE80)
        : (expired ? const Color(0xFFFF7C98) : const Color(0xFFFBBF24));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: orgText(
              p,
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 26),
            alignment: Alignment.center,
            child: Text(
              label,
              style: orgText(
                p,
                size: 15,
                weight: FontWeight.w700,
                color: const Color(0xFF4C1D95),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.value,
    this.first = false,
  });

  final String label;
  final String value;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: orgText(p, size: 15, color: p.textSecondary),
            ),
          ),
          Text(value, style: orgText(p, size: 15, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
