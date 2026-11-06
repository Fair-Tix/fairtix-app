import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/sample_notifications.dart';
import '../../data/sample_tickets.dart';
import '../../models/app_notification.dart';
import '../../models/ticket.dart';
import '../../services/notification_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_subpage_ui.dart';
import 'account_activated_screen.dart';
import 'ticket_sold_screen.dart';

/// True for the "your account is verified" notification the database writes
/// when an admin approves an eventgoer (see trg_notify_user_review in
/// supabase/notification_functions.sql). Matched by title because the table
/// has no separate subtype; it recognises both the current wording
/// ("Account activated") and "You're verified".
bool isVerificationSuccessNotification(AppNotification n) {
  if (!n.isRemote || n.type != AppNotificationType.system) return false;
  final title = n.title.toLowerCase().replaceAll('’', "'").trim();
  return title == 'account activated' || title.startsWith("you're verified");
}

/// Which notifications the list shows.
enum _NotifFilter {
  all('All'),
  tickets('Tickets'),
  resale('Resale'),
  system('System');

  const _NotifFilter(this.label);

  final String label;

  bool matches(AppNotification n) => switch (this) {
        _NotifFilter.all => true,
        _NotifFilter.tickets => n.type == AppNotificationType.ticket,
        _NotifFilter.resale =>
          n.type == AppNotificationType.resale || n.type == AppNotificationType.ticketSold,
        _NotifFilter.system => n.type == AppNotificationType.system ||
            n.type == AppNotificationType.general ||
            n.type == AppNotificationType.promo,
      };
}

/// In-app notification feed, shared by event goers, organizers and admins.
///
/// Shows the signed-in user's notifications from `public.notifications`
/// (see supabase/notification_functions.sql) — purchase, resale listing and
/// sale, cancellation, refund, account review, etc. Tapping a notification
/// marks it as read and the change is saved to the database, so it stays
/// read after a restart. Pull down to refresh.
///
/// The local demo "ticket sold" entries created by the resale flow
/// ([sampleNotifications]) are still listed first and keep their original
/// behavior (tap opens the Ticket Sold confirmation) until resale itself
/// is backed by Supabase.
///
/// Dark design: round back button, "Read all", All / Tickets / Resale /
/// System chips, and one grouped card with an unread dot per new item.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _remote = [];
  bool _isLoading = true;
  String? _errorMessage;
  _NotifFilter _filter = _NotifFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final list = await NotificationRepository.instance.fetch();
      if (!mounted) return;
      setState(() {
        _remote = list;
        _errorMessage = null;
      });
    } on NotificationRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasUnread => _remote.any((n) => !n.isRead) || sampleNotifications.any((n) => !n.isRead);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAllRead() async {
    final previous = _remote;
    setState(() {
      _remote = [for (final n in _remote) n.copyWith(isRead: true)];
      for (var i = 0; i < sampleNotifications.length; i++) {
        sampleNotifications[i] = sampleNotifications[i].copyWith(isRead: true);
      }
    });
    try {
      await NotificationRepository.instance.markAllRead();
    } on NotificationRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _remote = previous);
      _showMessage(e.message);
    }
  }

  Future<void> _handleRemoteTap(AppNotification notification) async {
    if (notification.isRead) return;
    final index = _remote.indexWhere((n) => n.id == notification.id);
    if (index == -1) return;
    setState(() => _remote[index] = notification.copyWith(isRead: true));
    try {
      await NotificationRepository.instance.markRead(notification.id);
    } on NotificationRepositoryException catch (e) {
      if (!mounted) return;
      // Couldn't save it — put the unread dot back so the screen doesn't
      // claim something that isn't true.
      setState(() => _remote[index] = notification);
      _showMessage(e.message);
    }
  }

  void _handleLocalTap(AppNotification notification) {
    final index = sampleNotifications.indexWhere((n) => n.id == notification.id);
    if (index != -1 && !sampleNotifications[index].isRead) {
      setState(() => sampleNotifications[index] = sampleNotifications[index].copyWith(isRead: true));
    }

    if (notification.type != AppNotificationType.ticketSold) return;
    Ticket? ticket;
    for (final t in sampleMyTickets) {
      if (t.id == notification.relatedTicketId) {
        ticket = t;
        break;
      }
    }
    if (ticket == null) return;

    // Simulate the resale completing: the ticket leaves the seller's
    // wallet (ownership has transferred to the buyer). The one-ticket-per-
    // account purchase limit is enforced server-side, so nothing else to
    // record locally.
    sampleMyTickets.removeWhere((t) => t.id == ticket!.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketSoldScreen(
          ticket: ticket!,
          // TODO(backend): resolve the real buyer from the resale
          // TRANSACTIONS record's buyer_id once the resale backend is
          // wired up. TicketSoldScreen doesn't currently display this
          // name (it just shows a "Confirmed" badge), so this is a safe
          // non-identifying placeholder in the meantime.
          buyerName: 'A verified buyer',
          salePrice: ticket.resalePrice ?? ticket.tier.price,
        ),
      ),
    );
  }

  void _handleTap(AppNotification notification) {
    if (notification.isRemote) {
      _handleRemoteTap(notification);
      if (isVerificationSuccessNotification(notification)) {
        Navigator.of(context).push(ftSlideFadeRoute(const AccountActivatedScreen()));
      }
    } else {
      _handleLocalTap(notification);
    }
  }

  List<Widget> _content(FtAuthTheme t, List<AppNotification> all) {
    if (_isLoading) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator(color: t.activeAccent)),
        ),
      ];
    }

    if (_errorMessage != null && all.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center, style: t.subtitle()),
              const SizedBox(height: 10),
              TextButton(onPressed: _load, child: Text('Try again', style: t.link())),
            ],
          ),
        ),
      ];
    }

    final visible = all.where(_filter.matches).toList();
    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: t.activeAccent.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                all.isEmpty ? 'No notifications yet' : 'Nothing under ${_filter.label} yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: t.titleColor,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      Container(
        decoration: BoxDecoration(
          color: t.surfaceFill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        // The Material sits above the card's fill so the tap ripple shows.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, indent: 22, endIndent: 22, color: t.divider),
                _NotificationRow(
                  notification: visible[i],
                  onTap: () => _handleTap(visible[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final all = [...sampleNotifications, ..._remote];

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: t.overlayStyle,
        child: Scaffold(
          backgroundColor: t.bgBottom,
          body: FtAuthBackground(
            theme: t,
            child: SafeArea(
              child: Center(
                // Keep the feed readable on wide web screens instead of
                // stretching each card edge to edge.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: RefreshIndicator(
                    color: t.activeAccent,
                    backgroundColor: t.surfaceFill,
                    onRefresh: () => _load(showSpinner: false),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                      children: [
                        Stack(
                          children: [
                            FtPageHeader(
                              title: 'Notifications',
                              onBack: () => Navigator.of(context).maybePop(),
                            ),
                            if (_hasUnread)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: TextButton(
                                    onPressed: _markAllRead,
                                    child: Text(
                                      'Read all',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: t.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _FilterChips(
                          selected: _filter,
                          onSelected: (f) => setState(() => _filter = f),
                        ),
                        const SizedBox(height: 22),
                        ..._content(t, all),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The All / Tickets / Resale / System pills. The selected one is filled
/// with the brand purple gradient.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _NotifFilter selected;
  final ValueChanged<_NotifFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    // Scales down only on very narrow screens so no chip gets cut off.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final filter in _NotifFilter.values) ...[
            if (filter != _NotifFilter.all) const SizedBox(width: 8),
            _chip(t, filter),
          ],
        ],
      ),
    );
  }

  Widget _chip(FtAuthTheme t, _NotifFilter filter) {
    final isSelected = filter == selected;
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      selected: isSelected,
      label: filter.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: isSelected ? FairTixPalette.buttonGradient : null,
          color: isSelected ? null : t.surfaceFill,
          border: isSelected ? null : Border.all(color: t.surfaceBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onSelected(filter),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: Text(
                filter.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? Colors.white : t.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One notification: unread dot, title, time, and the message underneath.
/// The "you're verified" notification keeps its green dot and opens the
/// success screen when tapped (see [_NotificationsScreenState._handleTap]).
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final unread = !notification.isRead;
    final verified = isVerificationSuccessNotification(notification);
    final dotColor = verified ? t.success : t.activeAccent;

    return Semantics(
      button: true,
      label: '${unread ? 'Unread. ' : ''}${notification.title}. ${notification.message}',
      hint: verified ? 'Opens your verification status' : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: unread
                      ? Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              height: 1.25,
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                              color: t.titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            notification.timeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              color: t.subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        height: 1.4,
                        color: t.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
