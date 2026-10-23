import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import '../../models/subscription_plan.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import '../../services/subscription_plan_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import '../../widgets/theme_mode_switch.dart';
import 'app_colors.dart' show formatFriendlyDate;
import 'organizer-change-password.dart';
import 'organizer-scaffold.dart';
import 'organizer-splash.dart';
import 'organizer-subscription-plan.dart';

/// Organizer Profile Settings (Mahilum design): identity card + log out on
/// the left, subscription card and account details on the right.
class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  SubscriptionPlan? _plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  /// The plan's limits come from the plans table (the account only stores the
  /// plan name and fee rate). If it can't be loaded, the card shows the fee
  /// chip alone.
  Future<void> _loadPlan() async {
    final name = OrganizerSession.instance.account?.subscriptionPlan;
    if (name == null) return;
    try {
      final plan = await SubscriptionPlanService.instance.fetchPlanByName(name);
      if (!mounted) return;
      setState(() => _plan = plan);
    } on SubscriptionPlanException {
      // Keep the fallback chips.
    } catch (_) {
      // Same: never block the profile on the plan lookup.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final wide = MediaQuery.of(context).size.width >= 1000;
    final account = OrganizerSession.instance.account;

    final left = _leftColumn(context, p, account);
    final right = _rightColumn(context, p, account);

    return OrganizerScaffold(
      pageTitle: 'Profile Settings',
      activeItem: OrganizerNavItem.profile,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: orgText(p, size: 15, color: p.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Profile Settings',
                      style: orgText(
                        p,
                        size: 36,
                        weight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeModeSwitch(),
            ],
          ),
          const SizedBox(height: 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 8, child: right),
              ],
            )
          else ...[left, const SizedBox(height: 24), right],
        ],
      ),
    );
  }

  // --- left ----------------------------------------------------------------

  Widget _leftColumn(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    final approved = account?.isApproved ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FairTixPalette.buttonGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  account?.avatarInitial ?? '?',
                  style: orgText(
                    p,
                    size: 52,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                account?.organizationName ?? 'Organizer',
                textAlign: TextAlign.center,
                style: orgText(p, size: 24, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                account?.email ?? '',
                textAlign: TextAlign.center,
                style: orgText(
                  p,
                  size: 15,
                  weight: FontWeight.w600,
                  color: p.accentLabel,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: approved ? p.successSurface : p.warningSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      approved ? Icons.check_rounded : Icons.schedule_rounded,
                      size: 16,
                      color: approved ? p.success : p.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      approved ? 'Verified Organizer' : 'Pending approval',
                      style: orgText(
                        p,
                        size: 14,
                        weight: FontWeight.w700,
                        color: approved ? p.success : p.warning,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _LogOutButton(onTap: () => _confirmLogOut(context)),
      ],
    );
  }

  void _confirmLogOut(BuildContext context) {
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
                MaterialPageRoute(
                  builder: (_) => const OrganizerSplashScreen(),
                ),
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

  // --- right ---------------------------------------------------------------

  Widget _rightColumn(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _subscriptionCard(context, p, account),
        const SizedBox(height: 24),
        _detailsCard(context, p, account),
      ],
    );
  }

  Widget _subscriptionCard(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    final hasPlan = account?.subscriptionPlan != null;
    final active = account?.hasActiveSubscription ?? false;
    final expired = account?.subscriptionExpired ?? false;

    final chips = <String>[];
    final plan = _plan;
    if (plan != null) {
      chips.add(
        plan.maxEventsPerMonth == null
            ? 'Unlimited events'
            : 'Up to ${plan.maxEventsPerMonth} events / month',
      );
      chips.add(
        plan.maxTicketsPerDay == null
            ? 'Unlimited tickets / day'
            : '${_n(plan.maxTicketsPerDay!)} tickets / day',
      );
      chips.add(
        plan.maxMultiDayDays == null
            ? 'Unlimited days per multi-day event'
            : 'Up to ${plan.maxMultiDayDays} days per multi-day event',
      );
      chips.add('${_pct(plan.feeRate)}% platform fee');
    } else if (account?.subscriptionFeeRate != null) {
      chips.add('${_pct(account!.subscriptionFeeRate!)}% platform fee');
    }

    final String badge = !hasPlan
        ? 'No Plan'
        : (active ? 'Active' : (expired ? 'Expired' : 'Inactive'));

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
                      'Subscription plan',
                      style: orgText(p, size: 15, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPlan
                          ? '${account!.subscriptionPlan} Plan \u2014 Monthly'
                          : 'No active plan',
                      style: orgText(
                        p,
                        size: 30,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account?.subscriptionRenewsAt != null
                          ? 'Next renewal: ${formatFriendlyDate(account!.subscriptionRenewsAt!)}'
                          : 'Choose a plan to get started',
                      style: orgText(p, size: 15, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? const Color(0xFF4ADE80)
                            : Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      badge,
                      style: orgText(
                        p,
                        size: 14,
                        weight: FontWeight.w700,
                        color: active ? const Color(0xFF86EFAC) : Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final c in chips) _PlanChip(label: c)],
            ),
          ],
          const SizedBox(height: 26),
          _WhiteButton(
            label: 'Manage Subscription',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrganizerSubscriptionPlanScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(
    BuildContext context,
    FairTixPalette p,
    OrganizerAccount? account,
  ) {
    return OrganizerCard(
      radius: 28,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account Details',
            style: orgText(p, size: 22, weight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, c) {
              final fields = [
                _LockedField(label: 'Full Name', value: account?.fullName ?? ''),
                _LockedField(
                  label: 'Email Address',
                  value: account?.email ?? '',
                ),
              ];
              if (c.maxWidth < 520) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: 18),
                    fields[1],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 20),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'These fields are locked to your verified identity documents.',
            style: orgText(
              p,
              size: 14,
              color: p.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          _LinkRow(
            label: 'Change Password',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrganizerChangePasswordScreen(),
                ),
              );
            },
          ),
          _LinkRow(
            label: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support is coming soon.')),
              );
            },
          ),
        ],
      ),
    );
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

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: orgText(
          p,
          size: 14,
          weight: FontWeight.w600,
          color: Colors.white,
          height: 1.1,
        ),
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

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(18);

    return Material(
      color: p.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.danger.withValues(alpha: 0.7)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: p.danger),
              const SizedBox(width: 12),
              Text(
                'Log Out',
                style: orgText(
                  p,
                  size: 16,
                  weight: FontWeight.w700,
                  color: p.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrganizerFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 15, color: p.textSecondary),
                ),
              ),
              Icon(Icons.lock_outline_rounded, size: 18, color: p.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: orgText(p, size: 16, weight: FontWeight.w700),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}
