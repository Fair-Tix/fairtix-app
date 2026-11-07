import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../navigation/tab_index_notifier.dart';
import '../../services/ticket_repository.dart';
import '../../services/user_auth_service.dart';
import '../../services/user_session.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtPressScale, FtProfileAvatar;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import '../../widgets/ft_skeleton.dart';
import '../../widgets/ft_ticket_card.dart';
import '../../widgets/offline_copy_banner.dart';
import 'ticket_detail_screen.dart';

/// "My Tickets" tab — lists every ticket the current user owns, backed by
/// [TicketRepository] (real query against `public.tickets`). Follows the
/// Light / Dark switch.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

/// Filter tabs. "Active" means a valid ticket that can be used or listed.
enum _TicketFilter {
  all('All'),
  active('Active'),
  used('Used'),
  listed('Listed');

  const _TicketFilter(this.label);
  final String label;

  bool matches(Ticket t) => switch (this) {
        _TicketFilter.all => true,
        _TicketFilter.active => t.status == TicketStatus.valid,
        _TicketFilter.used => t.status == TicketStatus.used,
        _TicketFilter.listed => t.status == TicketStatus.listed,
      };
}

class _MyTicketsScreenState extends State<MyTicketsScreen>
    with TickerProviderStateMixin {
  static const int _revealMs = 650;
  static const int _revealCards = 6;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _revealMs),
  );
  bool _motionSet = false;
  bool _revealPlayed = false;

  bool _isLoading = true;
  String? _errorMessage;
  _TicketFilter _filter = _TicketFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    mainShellTabIndex.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionSet) return;
    _motionSet = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
      _revealPlayed = true;
    }
  }

  @override
  void dispose() {
    mainShellTabIndex.removeListener(_onTabChanged);
    _reveal.dispose();
    super.dispose();
  }

  // This tab stays alive inside the shell's PageView, so initState only
  // runs once. Without this, a ticket bought or listed elsewhere keeps
  // its old status here until the user pulls to refresh.
  void _onTabChanged() {
    if (mainShellTabIndex.value == 1) _refreshSilently();
  }

  /// Reloads without the full-screen loading state. If it fails, whatever is
  /// already on screen stays put.
  Future<void> _refreshSilently() async {
    try {
      await TicketRepository.instance.refresh();
      if (!mounted) return;
      setState(() => _errorMessage = null);
    } on TicketRepositoryException {
      // Keep showing the current list.
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await TicketRepository.instance.refresh();
    } on TicketRepositoryException catch (e) {
      _errorMessage = e.message;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // The cards rise in the first time they appear; later refreshes,
        // filter changes and tab returns don't replay it.
        if (!_revealPlayed) {
          _revealPlayed = true;
          _reveal.forward(from: 0);
        }
      }
    }
  }

  void _openTicket(BuildContext context, Ticket ticket) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => TicketDetailScreen(ticket: ticket)))
        // Fires when the ticket screen (or a resale flow opened from it) is
        // closed, so a status change made there shows up here.
        .then((_) => _refreshSilently());
  }

  @override
  Widget build(BuildContext context) {
    final all = TicketRepository.instance.tickets;
    final tickets = all.where(_filter.matches).toList();
    // Live tickets (valid / listed) first, soonest event on top; used and
    // canceled ones go to a quieter list below.
    final upcoming = tickets
        .where((x) => x.status == TicketStatus.valid || x.status == TicketStatus.listed)
        .toList()
      ..sort((a, b) => a.event.eventDateTime.compareTo(b.event.eventDateTime));
    final past = tickets
        .where((x) => x.status == TicketStatus.used || x.status == TicketStatus.canceled)
        .toList();

    final account = UserSession.instance.account;
    final firstName = (account?.fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final initial = firstName.isEmpty ? 'E' : firstName.substring(0, 1).toUpperCase();
    final photoPath = account?.profilePhotoUrl;
    final photoUrl =
        photoPath == null ? null : UserAuthService.instance.profilePhotoPublicUrl(photoPath);

    final showOffline =
        !_isLoading && _errorMessage == null && TicketRepository.instance.isFromCache;
    final t = FtAuthTheme.live(context);

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: t.activeAccent,
              backgroundColor: t.surfaceFill,
              onRefresh: _loadTickets,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(19, 18, 19, 28),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'My Tickets',
                                style: FtText.title().copyWith(
                                  fontSize: 30,
                                  letterSpacing: -0.6,
                                  color: t.titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tickets you\u2019ve purchased or received',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                height: 1.3,
                                color: t.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FtProfileAvatar(
                        initial: initial,
                        photoUrl: photoUrl,
                        onTap: () => mainShellTabIndex.value = 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: t.surfaceBorder)),
                    ),
                    child: Row(
                      children: [
                        for (final f in _TicketFilter.values)
                          _FilterTab(
                            label: f.label,
                            selected: f == _filter,
                            onTap: () => setState(() => _filter = f),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (showOffline) ...[
                    OfflineCopyBanner(
                      dark: t.isDark,
                      lastSyncedAt: TicketRepository.instance.lastSyncedAt,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading && all.isEmpty)
                    const FtShimmer(
                      semanticLabel: 'Loading your tickets',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FtSkeletonTicketCard(),
                          SizedBox(height: 16),
                          FtSkeletonTicketCard(),
                          SizedBox(height: 16),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    _Message(
                      text: _errorMessage!,
                      actionLabel: 'Try again',
                      onAction: _loadTickets,
                    )
                  else if (all.isEmpty)
                    const _Message(
                      icon: Icons.confirmation_number_outlined,
                      title: 'No tickets yet',
                      text: 'Tickets you buy will show up here.',
                    )
                  else if (tickets.isEmpty)
                    _Message(
                      icon: Icons.confirmation_number_outlined,
                      title: 'No ${_filter.label.toLowerCase()} tickets',
                      text: 'Try another filter to see the rest.',
                    )
                  else ...[
                    for (var i = 0; i < upcoming.length; i++) ...[
                      _wrapReveal(
                        i,
                        _TicketCard(
                          ticket: upcoming[i],
                          onTap: () => _openTicket(context, upcoming[i]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (past.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 10),
                        child: Text(
                          'PAST AND CANCELED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.2,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w800,
                            color: t.secondaryText,
                          ),
                        ),
                      ),
                      _wrapReveal(
                        upcoming.length,
                        _PastTicketList(
                          tickets: past,
                          onOpen: (ticket) => _openTicket(context, ticket),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _wrapReveal(int index, Widget child) {
    if (index >= _revealCards) return child;
    return FtReveal(
      animation: _reveal,
      startMs: index * 50,
      endMs: index * 50 + 300,
      totalMs: _revealMs,
      slide: 12,
      child: child,
    );
  }
}

/// Underlined tab for the All / Active / Used / Listed filter.
class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tickets',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? t.activeAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? t.titleColor : t.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

// Card pieces live in widgets/ft_ticket_card.dart (shared with the Resale
// Market); these aliases keep the names used below.
typedef _EventArt = FtEventArt;

({String label, Color color}) _statusOf(Ticket ticket, FtAuthTheme t) => switch (ticket.status) {
      TicketStatus.valid => (label: 'Valid', color: t.success),
      TicketStatus.listed => (label: 'Listed', color: t.activeAccent),
      TicketStatus.used => (label: 'Used', color: t.secondaryText),
      TicketStatus.canceled => (label: 'Canceled', color: t.danger),
    };

/// "Starts in 30 days" style line for the card footer.
String _startsLabel(EventSummary e) {
  final now = DateTime.now();
  if (e.timeLabel == null) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(e.eventDateTime.year, e.eventDateTime.month, e.eventDateTime.day);
    final d = day.difference(today).inDays;
    if (d < 0) return 'Event started';
    if (d == 0) return 'Happening today';
    if (d == 1) return 'Starts tomorrow';
    return 'Starts in $d days';
  }
  final diff = e.eventDateTime.difference(now);
  if (diff.isNegative) return 'Event started';
  if (diff.inDays >= 1) {
    final d = diff.inDays;
    return 'Starts in $d ${d == 1 ? 'day' : 'days'}';
  }
  if (diff.inHours >= 1) return 'Starts in ${diff.inHours} h';
  return 'Starts soon';
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final status = _statusOf(ticket, t);
    final event = ticket.event;
    final isListed = ticket.status == TicketStatus.listed;
    final footerText = isListed
        ? (ticket.resalePrice != null
            ? 'Listed for ${formatPeso(ticket.resalePrice!)}'
            : 'Listed for resale')
        : _startsLabel(event);

    return FtTicketCard(
      event: event,
      tierName: ticket.tier.name,
      seatingLabel: ticket.tier.seatingLabel,
      chipLabel: status.label,
      chipColor: status.color,
      semanticLabel: '${event.title}, ${ticket.tier.name}, ${event.dateLabel}, '
          '${status.label}. View details',
      onTap: onTap,
      footer: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          footerText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: t.secondaryText,
          ),
        ),
      ),
      action: FtTicketButton(
        label: isListed ? 'View details' : 'View ticket',
        icon: isListed ? null : Icons.qr_code_2_rounded,
      ),
    );
  }
}

/// Used and canceled tickets: one bordered list of compact, muted rows.
class _PastTicketList extends StatelessWidget {
  const _PastTicketList({required this.tickets, required this.onOpen});

  final List<Ticket> tickets;
  final void Function(Ticket) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.isDark ? t.surfaceFill.withValues(alpha: 0.5) : t.surfaceFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < tickets.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.surfaceBorder),
            _PastTicketRow(ticket: tickets[i], onTap: () => onOpen(tickets[i])),
          ],
        ],
      ),
    );
  }
}

class _PastTicketRow extends StatelessWidget {
  const _PastTicketRow({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final status = _statusOf(ticket, t);
    final event = ticket.event;
    return Semantics(
      button: true,
      label: '${event.title}, ${ticket.tier.name}, ${event.dayLabel}, '
          '${status.label}. View details',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _EventArt(event: event, initialsSize: 18),
                      ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: t.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.tier.name} \u00b7 ${event.dayLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.2,
                        color: t.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                status.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: status.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty / error message, in the current theme.
class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 46, color: t.activeAccent.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
          ],
          if (title != null) ...[
            Text(
              title!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.titleColor,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: t.subtitle().copyWith(color: t.secondaryText),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: t.link()),
            ),
        ],
      ),
    );
  }
}
