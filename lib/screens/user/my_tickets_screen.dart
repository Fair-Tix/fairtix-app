import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ticket.dart';
import '../../navigation/tab_index_notifier.dart';
import '../../services/ticket_repository.dart';
import '../../services/user_auth_service.dart';
import '../../services/user_session.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtPressScale, FtProfileAvatar;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
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

/// Filter chips. "Active" means a valid ticket that can be used or listed.
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
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
      _pulse.value = 1;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    mainShellTabIndex.removeListener(_onTabChanged);
    _reveal.dispose();
    _pulse.dispose();
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
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
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
                                  fontSize: 33,
                                  letterSpacing: -0.6,
                                  color: t.titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tickets you\u2019ve purchased or received',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (final f in _TicketFilter.values) ...[
                          _FilterChip(
                            label: f.label,
                            selected: f == _filter,
                            onTap: () => setState(() => _filter = f),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (showOffline) ...[
                    OfflineCopyBanner(
                      dark: t.isDark,
                      lastSyncedAt: TicketRepository.instance.lastSyncedAt,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading && all.isEmpty)
                    for (var i = 0; i < 3; i++) ...[
                      _SkeletonCard(pulse: _pulse),
                      const SizedBox(height: 14),
                    ]
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
                  else
                    for (var i = 0; i < tickets.length; i++) ...[
                      _wrapReveal(
                        i,
                        _TicketCard(
                          ticket: tickets[i],
                          onTap: () => _openTicket(context, tickets[i]),
                        ),
                      ),
                      const SizedBox(height: 14),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tickets',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [FtColors.progressStart, FtColors.otpButtonEnd],
                  )
                : null,
            color: selected
                ? null
                : (t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill),
            border: Border.all(
              color: selected ? Colors.transparent : t.surfaceBorder,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? Colors.white : t.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed card geometry: a 100px top part, a perforation line with a notch at
/// each edge, and a 58px bottom part.
const double _kTopHeight = 100;
const double _kBottomHeight = 58;
const double _kNotchRadius = 11;

/// Draws the ticket-shaped card: rounded rectangle with a half-circle bite
/// out of each side at the perforation, a border around that shape, and the
/// dashed line between the notches.
class _TicketShapePainter extends CustomPainter {
  _TicketShapePainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)));
    final bites = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, _kTopHeight), radius: _kNotchRadius))
      ..addOval(Rect.fromCircle(center: Offset(size.width, _kTopHeight), radius: _kNotchRadius));
    final shape = Path.combine(PathOperation.difference, card, bites);

    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );

    final dash = Paint()
      ..color = border
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var x = _kNotchRadius + 14;
    final end = size.width - _kNotchRadius - 14;
    while (x < end) {
      canvas.drawLine(
        Offset(x, _kTopHeight),
        Offset((x + 5).clamp(0, end).toDouble(), _kTopHeight),
        dash,
      );
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_TicketShapePainter old) => old.fill != fill || old.border != border;
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  ({String label, Color color}) _status(FtAuthTheme t) => switch (ticket.status) {
        TicketStatus.valid => (label: 'Valid', color: t.success),
        TicketStatus.listed => (label: 'Listed', color: t.activeAccent),
        TicketStatus.used => (label: 'Used', color: t.secondaryText),
        TicketStatus.canceled => (label: 'Canceled', color: t.danger),
      };

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final status = _status(t);
    final accent = ticket.event.accentColor;
    final hsl = HSLColor.fromColor(accent);
    final deeper = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();

    return Semantics(
      button: true,
      label: '${ticket.event.title}, ${ticket.tier.name}, ${ticket.event.dateLabel}, '
          '${status.label}. View details',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: CustomPaint(
          painter: _TicketShapePainter(
            fill: t.isDark ? t.surfaceFill.withValues(alpha: 0.8) : t.surfaceFill,
            border: t.surfaceBorder,
          ),
          child: Column(
            children: [
              SizedBox(
                height: _kTopHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, deeper],
                          ),
                        ),
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: t.titleColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                                  constraints: const BoxConstraints(maxWidth: 96),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: const LinearGradient(
                                      colors: [FtColors.progressStart, FtColors.otpButtonEnd],
                                    ),
                                  ),
                                  child: Text(
                                    ticket.tier.name.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: t.secondaryText,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ticket.event.dateLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      height: 1.2,
                                      color: t.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: _kBottomHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.16),
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
                                color: status.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: status.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'View details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 20, color: t.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown on the first load, in the same ticket shape, gently
/// pulsing so the layout doesn't jump when the real cards arrive.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final wave = Curves.easeInOut.transform(pulse.value);
        final block = t.surfaceBorder.withValues(alpha: 0.35 + 0.3 * wave);
        Widget bar(double w, double h) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: block,
                borderRadius: BorderRadius.circular(8),
              ),
            );
        return CustomPaint(
          painter: _TicketShapePainter(fill: t.cardFill, border: t.surfaceBorder),
          child: SizedBox(
            height: _kTopHeight + _kBottomHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  SizedBox(
                    height: _kTopHeight,
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: block,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [bar(150, 16), const SizedBox(height: 12), bar(110, 12)],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _kBottomHeight,
                    child: Row(
                      children: [bar(72, 26), const Spacer(), bar(96, 14)],
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
