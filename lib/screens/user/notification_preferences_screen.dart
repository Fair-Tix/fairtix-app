import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_settings.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/ft_subpage_ui.dart';

/// "Notifications" settings — which channels (in-app, email, push) and which
/// kinds of notification the user wants. In-app notifications, ticket updates
/// and account/security alerts are transactional, so they stay on and their
/// switches are locked. Dark design that follows the Light / Dark switch.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  void _explainLocked() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('This one is always on so you never miss a purchase, refund or entry update.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final settings = notificationSettings;
    return FtSubpageScaffold(
      title: 'Notifications',
      onBack: () => Navigator.of(context).maybePop(),
      followTheme: true,
      body: [
        const FtSectionLabel('Channels'),
        const SizedBox(height: 12),
        FtSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _RowGroup(
            rows: [
              _ToggleRow(
                title: 'In-app',
                subtitle: 'Inside FairTix',
                value: true,
                locked: true,
                onLockedTap: _explainLocked,
              ),
              _ToggleRow(
                title: 'Email',
                subtitle: 'To your verified email',
                value: settings.emailEnabled,
                onChanged: (v) => setState(() => settings.emailEnabled = v),
              ),
              _ToggleRow(
                title: 'Push',
                subtitle: 'On this device',
                value: settings.pushEnabled,
                onChanged: (v) => setState(() => settings.pushEnabled = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const FtSectionLabel('What to notify me about'),
        const SizedBox(height: 12),
        FtSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _RowGroup(
            rows: [
              _ToggleRow(
                title: 'Tickets',
                subtitle: 'Purchases, QR updates, event changes',
                value: true,
                locked: true,
                onLockedTap: _explainLocked,
              ),
              _ToggleRow(
                title: 'Resale',
                subtitle: 'Listings, sales, expiries',
                value: settings.resaleActivityEnabled,
                onChanged: (v) => setState(() => settings.resaleActivityEnabled = v),
              ),
              _ToggleRow(
                title: 'Account',
                subtitle: 'Verification and security',
                value: true,
                locked: true,
                onLockedTap: _explainLocked,
              ),
              _ToggleRow(
                title: 'Promotions',
                subtitle: 'New events from organizers you bought from',
                value: settings.promoEnabled,
                onChanged: (v) => setState(() => settings.promoEnabled = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const FtNote(
          icon: Icons.lock_outline_rounded,
          text: 'Ticket, refund and account alerts can’t be turned off, so you never miss one.',
        ),
      ],
    );
  }
}

/// Rows separated by hairlines.
class _RowGroup extends StatelessWidget {
  const _RowGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
          rows[i],
        ],
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
    this.locked = false,
    this.onLockedTap,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Always on: the switch is dimmed and tapping it explains why.
  final bool locked;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    height: 1.3,
                    color: t.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _FtSwitch(
            label: title,
            value: value,
            locked: locked,
            onChanged: locked ? (_) => onLockedTap?.call() : onChanged,
          ),
        ],
      ),
    );
  }
}

/// Purple pill switch with a white knob.
class _FtSwitch extends StatelessWidget {
  const _FtSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.locked = false,
  });

  final String label;
  final bool value;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      toggled: value,
      enabled: !locked,
      label: locked ? '$label, always on' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Opacity(
          opacity: locked ? 0.6 : 1,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
            width: 60,
            height: 34,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? FtColors.glow : (t.isDark ? t.progressTrack : t.surfaceBorder),
              borderRadius: BorderRadius.circular(17),
              border: value ? Border.all(color: FtColors.fieldBorderFocused, width: 1) : null,
            ),
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
