import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../screens/user/notifications_screen.dart';
import '../services/notification_repository.dart';
import '../services/organizer_session.dart';
import '../theme/fairtix_palette.dart';
import 'organizer_ui.dart';

/// Top-bar dropdowns for the organizer screens: the notification bell and the
/// profile avatar. Both open a small floating panel under their button.

Future<void> _showDropdown(
  BuildContext anchor, {
  required double width,
  required Widget Function(BuildContext ctx, FairTixPalette p, double maxHeight)
  builder,
}) {
  final box = anchor.findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero);
  final screen = MediaQuery.of(anchor).size;
  final p = FairTixPalette.of(anchor);
  final right = (screen.width - origin.dx - box.size.width)
      .clamp(12.0, screen.width)
      .toDouble();
  final top = origin.dy + box.size.height + 10;
  final w = width.clamp(0.0, screen.width - 24).toDouble();
  final maxHeight = (screen.height - top - 16).clamp(200.0, 720.0).toDouble();

  return showGeneralDialog<void>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (ctx, a1, a2) => Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          width: w,
          child: Material(
            type: MaterialType.transparency,
            child: builder(ctx, p, maxHeight),
          ),
        ),
      ],
    ),
    transitionBuilder: (ctx, anim, a2, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

BoxDecoration _panelDecoration(FairTixPalette p) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: p.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.14),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Notification bell + dropdown
// ---------------------------------------------------------------------------

class OrganizerBellButton extends StatefulWidget {
  const OrganizerBellButton({super.key});

  @override
  State<OrganizerBellButton> createState() => _OrganizerBellButtonState();
}

class _OrganizerBellButtonState extends State<OrganizerBellButton> {
  Timer? _timer;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    NotificationRepository.instance.refreshUnreadCount();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => NotificationRepository.instance.refreshUnreadCount(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final navContext = context;
    setState(() => _open = true);
    await _showDropdown(
      context,
      width: 430,
      builder: (ctx, p, maxHeight) => _NotificationsPanel(
        p: p,
        maxHeight: maxHeight,
        onViewAll: () {
          Navigator.of(ctx).pop();
          Navigator.of(navContext).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
    );
    if (mounted) setState(() => _open = false);
    await NotificationRepository.instance.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: NotificationRepository.instance.unreadCount,
      builder: (context, count, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _open ? p.primary.withValues(alpha: 0.18) : p.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _open ? p.accentLabel : p.border,
                  width: _open ? 1.6 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: p.accentLabel,
                  ),
                  if (count > 0)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: p.surface, width: 1.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _NotifTab { all, sales, events, system }

_NotifTab _categoryOf(AppNotification n) {
  switch (n.type) {
    case AppNotificationType.ticket:
    case AppNotificationType.ticketSold:
    case AppNotificationType.resale:
      return _NotifTab.sales;
    case AppNotificationType.system:
      final text = '${n.title} ${n.message}'.toLowerCase();
      return text.contains('event') ? _NotifTab.events : _NotifTab.system;
    case AppNotificationType.promo:
    case AppNotificationType.general:
      return _NotifTab.system;
  }
}

IconData _iconOf(AppNotification n) {
  switch (n.type) {
    case AppNotificationType.ticket:
    case AppNotificationType.ticketSold:
      return Icons.confirmation_number_outlined;
    case AppNotificationType.resale:
      return Icons.swap_horiz_rounded;
    case AppNotificationType.promo:
      return Icons.sell_outlined;
    case AppNotificationType.system:
    case AppNotificationType.general:
      return Icons.verified_user_outlined;
  }
}

String _shortTime(String label) {
  if (label == 'Just now') return 'now';
  final m = RegExp(r'^(\d+) (min|hr|day|days) ago$').firstMatch(label);
  if (m == null) return label;
  final n = m.group(1);
  switch (m.group(2)) {
    case 'min':
      return '${n}m';
    case 'hr':
      return '${n}h';
    default:
      return '${n}d';
  }
}

class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel({
    required this.p,
    required this.maxHeight,
    required this.onViewAll,
  });

  final FairTixPalette p;
  final double maxHeight;
  final VoidCallback onViewAll;

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  List<AppNotification> _items = const [];
  bool _loading = true;
  _NotifTab _tab = _NotifTab.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await NotificationRepository.instance.fetch(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationRepository.instance.markAllRead();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _items = [for (final n in _items) n.copyWith(isRead: true)];
    });
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    setState(() {
      _items = [for (final i in _items) i.id == n.id ? i.copyWith(isRead: true) : i];
    });
    if (!n.isRemote) return;
    try {
      await NotificationRepository.instance.markRead(n.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final unread = _items.where((n) => !n.isRead).length;
    final shown = _items
        .where((n) => _tab == _NotifTab.all || _categoryOf(n) == _tab)
        .take(6)
        .toList();

    const labels = {
      _NotifTab.all: 'All',
      _NotifTab.sales: 'Sales',
      _NotifTab.events: 'Events',
      _NotifTab.system: 'System',
    };

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: _panelDecoration(p),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: orgText(p, size: 17, weight: FontWeight.w800),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unread new',
                      style: orgText(
                        p,
                        size: 11,
                        weight: FontWeight.w700,
                        color: p.accentLabel,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                OrganizerTextLink(
                  label: 'Mark all read',
                  size: 13,
                  onTap: unread > 0 ? _markAllRead : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _NotifTab.values)
                  _TabChip(
                    label: labels[t]!,
                    selected: t == _tab,
                    onTap: () => setState(() => _tab = t),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (shown.isEmpty)
            _EmptyState(p: p)
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: shown.length,
                separatorBuilder: (_, i) => Divider(height: 1, color: p.border),
                itemBuilder: (_, i) => _NotificationRow(
                  p: p,
                  item: shown[i],
                  onTap: () => _markRead(shown[i]),
                ),
              ),
            ),
          Divider(height: 1, color: p.border),
          InkWell(
            onTap: widget.onViewAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'View all notifications',
                  style: orgText(
                    p,
                    size: 14,
                    weight: FontWeight.w700,
                    color: p.accentLabel,
                    height: 1.2,
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

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? p.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? p.primary : p.border),
          ),
          child: Text(
            label,
            style: orgText(
              p,
              size: 13,
              weight: FontWeight.w600,
              color: selected ? Colors.white : p.textPrimary,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.p});

  final FairTixPalette p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrganizerStatusIcon(
            icon: Icons.verified_user_outlined,
            color: p.accentLabel,
            background: p.primary.withValues(alpha: 0.22),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'You\u2019re all caught up',
            style: orgText(p, size: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Ticket sales, event updates and announcements will show up here.',
            textAlign: TextAlign.center,
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.p,
    required this.item,
    required this.onTap,
  });

  final FairTixPalette p;
  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead ? null : p.primary.withValues(alpha: 0.10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(_iconOf(item), size: 18, color: p.accentLabel),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 13,
                      color: p.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _shortTime(item.timeLabel),
                  style: orgText(p, size: 12, color: p.textSecondary),
                ),
                if (!item.isRead) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.accentLabel,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile avatar + dropdown
// ---------------------------------------------------------------------------

/// Public entry points to the dropdown styling above, so other top bars (the
/// admin shell) can reuse the exact same panel, positioning and menu rows.
Future<void> showTopMenuDropdown(
  BuildContext anchor, {
  required double width,
  required Widget Function(BuildContext ctx, FairTixPalette p, double maxHeight)
  builder,
}) => _showDropdown(anchor, width: width, builder: builder);

BoxDecoration topMenuPanelDecoration(FairTixPalette p) => _panelDecoration(p);

class TopMenuItem extends StatelessWidget {
  const TopMenuItem({
    super.key,
    required this.p,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.danger = false,
  });

  final FairTixPalette p;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _MenuItem(
    p: p,
    icon: icon,
    title: title,
    subtitle: subtitle,
    badge: badge,
    badgeColor: badgeColor,
    danger: danger,
    onTap: onTap,
  );
}

class OrganizerProfileMenuActions {
  const OrganizerProfileMenuActions({
    required this.onProfile,
    required this.onMyEvents,
    required this.onSubscription,
    required this.onSettings,
    required this.onSignOut,
    this.onHelp,
  });

  final VoidCallback onProfile;
  final VoidCallback onMyEvents;
  final VoidCallback onSubscription;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;

  /// Null hides the Help & Support item (no contact channel to send people to).
  final VoidCallback? onHelp;
}

class OrganizerAvatarButton extends StatefulWidget {
  const OrganizerAvatarButton({
    super.key,
    required this.initial,
    required this.actions,
    this.color,
    this.highlighted = false,
  });

  final String initial;
  final OrganizerProfileMenuActions actions;
  final Color? color;

  /// Show the ring even when the menu is closed (e.g. on the Profile page).
  final bool highlighted;

  @override
  State<OrganizerAvatarButton> createState() => _OrganizerAvatarButtonState();
}

class _OrganizerAvatarButtonState extends State<OrganizerAvatarButton> {
  bool _open = false;

  Future<void> _toggle() async {
    setState(() => _open = true);
    await _showDropdown(
      context,
      width: 340,
      builder: (ctx, p, maxHeight) {
        void run(VoidCallback action) {
          Navigator.of(ctx).pop();
          action();
        }

        final a = widget.actions;
        return _ProfilePanel(
          p: p,
          maxHeight: maxHeight,
          onProfile: () => run(a.onProfile),
          onMyEvents: () => run(a.onMyEvents),
          onSubscription: () => run(a.onSubscription),
          onSettings: () => run(a.onSettings),
          onHelp: a.onHelp == null ? null : () => run(a.onHelp!),
          onSignOut: () => run(a.onSignOut),
        );
      },
    );
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final ring = _open || widget.highlighted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ring ? p.accentLabel : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              gradient: widget.color == null
                  ? FairTixPalette.buttonGradient
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.initial,
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

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.p,
    required this.maxHeight,
    required this.onProfile,
    required this.onMyEvents,
    required this.onSubscription,
    required this.onSettings,
    required this.onHelp,
    required this.onSignOut,
  });

  final FairTixPalette p;
  final double maxHeight;
  final VoidCallback onProfile;
  final VoidCallback onMyEvents;
  final VoidCallback onSubscription;
  final VoidCallback onSettings;
  final VoidCallback? onHelp;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final account = OrganizerSession.instance.account;
    final approved = account?.isApproved ?? false;

    // The Subscription badge shows the organizer's real standing, not a label.
    final String planSubtitle;
    final String planBadge;
    final Color planBadgeColor;
    if (account != null && account.hasActiveSubscription) {
      final name = account.subscriptionPlan ?? '';
      planSubtitle = '$name plan \u00B7 Active';
      planBadge = name.toUpperCase();
      planBadgeColor = p.accentLabel;
    } else if (account != null && account.subscriptionExpired) {
      planSubtitle = 'Plan expired \u00B7 Renew to unlock events';
      planBadge = 'EXPIRED';
      planBadgeColor = p.danger;
    } else {
      planSubtitle = 'No active plan';
      planBadge = 'NO PLAN';
      planBadgeColor = p.warning;
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: _panelDecoration(p),
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
                          account?.organizationName ?? 'Organizer',
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
                          account?.email ?? '',
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
                            color: approved
                                ? p.successSurface
                                : p.warningSurface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                approved
                                    ? Icons.verified_user_outlined
                                    : Icons.schedule_rounded,
                                size: 12,
                                color: approved ? p.success : p.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                approved ? 'Verified' : 'Pending',
                                style: orgText(
                                  p,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: approved ? p.success : p.warning,
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
                      account?.avatarInitial ?? '?',
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
            _MenuItem(
              p: p,
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Organization and account details',
              onTap: onProfile,
            ),
            _MenuItem(
              p: p,
              icon: Icons.event_available_outlined,
              title: 'My Events',
              subtitle: 'Events and ticket setup',
              onTap: onMyEvents,
            ),
            _MenuItem(
              p: p,
              icon: Icons.credit_card_rounded,
              title: 'Subscription',
              subtitle: planSubtitle,
              badge: planBadge,
              badgeColor: planBadgeColor,
              onTap: onSubscription,
            ),
            _MenuItem(
              p: p,
              icon: Icons.tune_rounded,
              title: 'Settings',
              subtitle: 'Password, notifications, appearance',
              onTap: onSettings,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Divider(height: 1, color: p.border),
            ),
            if (onHelp != null)
              _MenuItem(
                p: p,
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'FAQs and contact FairTix',
                onTap: onHelp!,
              ),
            _MenuItem(
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

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.p,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.trailing,
    this.danger = false,
  });

  final FairTixPalette p;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final IconData? trailing;
  final bool danger;
  final VoidCallback onTap;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final titleColor = widget.danger ? p.danger : p.textPrimary;
    final iconColor = widget.danger ? p.danger : p.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hover ? p.primary.withValues(alpha: 0.22) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: orgText(
                        p,
                        size: 14,
                        weight: FontWeight.w700,
                        color: titleColor,
                        height: 1.25,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
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
              if (widget.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.badgeColor ?? p.primary).withValues(
                      alpha: widget.badgeColor == null ? 0.3 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.badge!,
                    style: orgText(
                      p,
                      size: 11,
                      weight: FontWeight.w800,
                      color: widget.badgeColor ?? p.accentLabel,
                      height: 1.2,
                    ),
                  ),
                ),
              if (widget.trailing != null)
                Icon(widget.trailing, size: 16, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
