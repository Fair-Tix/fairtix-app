import 'package:flutter/material.dart';

import '../../models/event.dart' show kResaleSellerFeeRate;
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';
import 'admin-subscription-plans-card.dart';

/// Platform Settings.
///
/// The only editable (and saved) setting is the set of organizer subscription
/// plans, which includes each plan's primary-sale fee rate
/// (`public.subscription_plans`, see supabase/subscription_plans.sql).
///
/// The old General / Payment / Security / Notifications cards were removed:
/// none of their controls (platform name, logo, a second fee rate, payout
/// schedule, session timeout, 2FA, email alerts, weekly digest) was saved or
/// read by anything, so "Save Changes" only showed a message. A control should
/// come back only together with the feature it controls.
class AdminPlatformSettingsScreen extends StatelessWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.platformSettings,
      title: 'Settings',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Platform Settings',
            subtitle: 'Subscription plans and the fee rules FairTix applies.',
            actions: const [],
          ),
          const SizedBox(height: 24),
          const _PlatformRulesCard(),
          const SizedBox(height: 20),
          const AdminSubscriptionPlansCard(),
        ],
      ),
    );
  }
}

/// "12%" / "5%" / "7.5%" from a fraction such as 0.05.
String _percentLabel(double rate) {
  final value = double.parse((rate * 100).toStringAsFixed(2));
  return value == value.roundToDouble()
      ? '${value.round()}%'
      : '${value.toStringAsFixed(1)}%';
}

/// Read-only summary of fee rules that are fixed in the app and database.
/// Nothing here can be edited or saved; the resale fee comes from the same
/// constant the resale screens use.
class _PlatformRulesCard extends StatelessWidget {
  const _PlatformRulesCard();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: FairTixPalette.buttonGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.rule_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Platform Rules',
                    style: orgText(p, size: 16, weight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Read-only',
                  style: orgText(p, size: 12, color: p.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ruleRow(
                  p,
                  'Resale fee',
                  '${_percentLabel(kResaleSellerFeeRate)} of the resale price, '
                      'deducted from the seller. Fixed for every plan.',
                ),
                const SizedBox(height: 16),
                _ruleRow(
                  p,
                  'Primary sale fee',
                  'Depends on the organizer’s plan. Edit each plan’s '
                      'fee rate in Subscription Plans below.',
                ),
                const SizedBox(height: 16),
                Text(
                  'These rules are set in the app and the database, so they '
                  'cannot be changed from this page.',
                  style: orgText(
                    p,
                    size: 12,
                    color: p.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(FairTixPalette p, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: orgText(p, size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          description,
          style: orgText(p, size: 13, color: p.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}
