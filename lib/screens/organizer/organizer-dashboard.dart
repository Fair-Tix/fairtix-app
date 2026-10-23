import 'package:flutter/material.dart';

import '../../models/organizer_event.dart';
import '../../services/access_control.dart';
import '../../services/event_repository.dart';
import '../../services/organizer_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-cancel-event.dart';
import 'organizer-create-event.dart';
import 'organizer-edit-event.dart';
import 'organizer-my-events.dart';
import 'organizer-scaffold.dart';
import 'organizer-scanner-session.dart';
import 'organizer-send-announcement.dart';

/// Organizer Dashboard (Mahilum design): welcome row with actions, a featured
/// event card, revenue / stat tiles, and a grid of the latest events.
class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException {
      // Non-fatal here: the dashboard just shows zeroed tiles / no events.
      // My Events is where a failed load gets a visible error + Retry.
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // --- navigation ----------------------------------------------------------

  Future<void> _sendAnnouncement() async {
    final allowed = await ensureOrganizerAccess(
      context,
      OrganizerRequirement.subscription,
    );
    if (!allowed || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganizerSendAnnouncementScreen(),
      ),
    );
  }

  Future<void> _createEvent() async {
    final allowed = await ensureOrganizerAccess(
      context,
      OrganizerRequirement.subscription,
    );
    if (!allowed || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerCreateEventScreen()),
    );
    _load();
  }

  void _manage(OrganizerEvent e) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => OrganizerEditEventScreen(eventId: e.id)),
  );

  void _scan(OrganizerEvent e) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrganizerScannerSessionScreen(eventId: e.id),
    ),
  );

  void _cancel(OrganizerEvent e) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrganizerCancelEventScreen(eventId: e.id),
    ),
  );

  void _viewAll() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const OrganizerMyEventsScreen()),
  );

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 1000;

    final account = OrganizerSession.instance.account;
    final organizerName = account?.fullName ?? 'Organizer';
    final locked =
        organizerLockMessage(account, OrganizerRequirement.subscription) !=
        null;

    final repo = EventRepository.instance;
    final events = repo.events;
    final featured = _pickFeatured(events);

    // Net of platform fees when the current plan's rate is known.
    final feeRate = account?.subscriptionFeeRate;
    final gross = repo.totalGrossRevenue;
    final hasNet = feeRate != null;
    final revenue = hasNet ? gross * (1 - feeRate) : gross;

    return OrganizerScaffold(
      pageTitle: 'Organizer Dashboard',
      activeItem: OrganizerNavItem.dashboard,
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(64),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: p.accentLabel,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  name: organizerName,
                  locked: locked,
                  onAnnouncement: _sendAnnouncement,
                  onCreate: _createEvent,
                ),
                const SizedBox(height: 24),
                _HeroRow(
                  wide: wide,
                  featured: featured,
                  revenue: revenue,
                  revenueLabel: hasNet ? 'Net of platform fees' : 'Before fees',
                  totalEvents: events.length,
                  ticketsSold: repo.totalTicketsSold,
                  onManage: _manage,
                  onScan: _scan,
                ),
                const SizedBox(height: 36),
                _MyEventsSection(
                  events: events,
                  onViewAll: _viewAll,
                  onManage: _manage,
                  onScan: _scan,
                  onCancel: _cancel,
                ),
              ],
            ),
    );
  }

  /// The event to feature: one running today, otherwise the next upcoming
  /// published one. Null when there is neither.
  _Featured? _pickFeatured(List<OrganizerEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _Featured? upcoming;
    DateTime? upcomingStart;

    for (final e in events) {
      if (e.status != EventStatus.published) continue;
      final range = _parseRange(e.date);
      if (range == null) continue;
      if (!today.isBefore(range.start) && !today.isAfter(range.end)) {
        return _Featured(e, 'Happening now');
      }
      if (range.start.isAfter(today) &&
          (upcomingStart == null || range.start.isBefore(upcomingStart))) {
        upcoming = _Featured(e, 'Up next');
        upcomingStart = range.start;
      }
    }
    return upcoming;
  }
}

class _Featured {
  const _Featured(this.event, this.label);
  final OrganizerEvent event;
  final String label;
}

/// Parses an [OrganizerEvent.date] label ("M/D/YYYY" or "M/D/YYYY – M/D/YYYY").
({DateTime start, DateTime end})? _parseRange(String label) {
  DateTime? one(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (m == null || d == null || y == null) return null;
    return DateTime(y, m, d);
  }

  final pieces = label.split('\u2013');
  final start = one(pieces.first);
  if (start == null) return null;
  final end = pieces.length > 1 ? (one(pieces[1]) ?? start) : start;
  return (start: start, end: end);
}

/// "Oct 14-17, 2026" style label for an event.
String _dateLabel(OrganizerEvent e) {
  final pieces = e.date.split('\u2013').map((s) => s.trim()).toList();
  final start = pieces.first;
  final end = pieces.length > 1 ? pieces[1] : start;
  return OrganizerEvent.formatDateRange(start, end, e.isMultiDay);
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.locked,
    required this.onAnnouncement,
    required this.onCreate,
  });

  final String name;
  final bool locked;
  final VoidCallback onAnnouncement;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome back',
              style: orgText(p, size: 15, color: p.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              name,
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OutlineAction(
              icon: Icons.campaign_outlined,
              label: 'Send Announcement',
              onTap: onAnnouncement,
            ),
            const SizedBox(width: 12),
            Opacity(
              opacity: locked ? 0.45 : 1,
              child: _GradientAction(
                icon: Icons.add_rounded,
                label: 'Create Event',
                onTap: onCreate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return Material(
      color: p.surface,
      borderRadius: radius,
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: p.textPrimary),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: orgText(p, size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientAction extends StatelessWidget {
  const _GradientAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: p.isDark ? 0.40 : 0.30),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: FairTixPalette.buttonGradient,
            borderRadius: radius,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: orgText(
                      p,
                      size: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero row: featured event + revenue / stat tiles
// ---------------------------------------------------------------------------

class _HeroRow extends StatelessWidget {
  const _HeroRow({
    required this.wide,
    required this.featured,
    required this.revenue,
    required this.revenueLabel,
    required this.totalEvents,
    required this.ticketsSold,
    required this.onManage,
    required this.onScan,
  });

  final bool wide;
  final _Featured? featured;
  final double revenue;
  final String revenueLabel;
  final int totalEvents;
  final int ticketsSold;
  final void Function(OrganizerEvent) onManage;
  final void Function(OrganizerEvent) onScan;

  @override
  Widget build(BuildContext context) {
    final stats = Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.calendar_today_outlined,
            label: 'Total Events',
            value: '$totalEvents',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatTile(
            icon: Icons.confirmation_number_outlined,
            label: 'Tickets Sold',
            value: '$ticketsSold',
          ),
        ),
      ],
    );
    final revenueCard = _RevenueCard(amount: revenue, caption: revenueLabel);

    final featuredCard = featured == null
        ? null
        : _FeaturedCard(
            featured: featured!,
            tall: wide,
            onManage: () => onManage(featured!.event),
            onScan: () => onScan(featured!.event),
          );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (featuredCard != null) ...[
            featuredCard,
            const SizedBox(height: 16),
          ],
          SizedBox(height: 170, child: revenueCard),
          const SizedBox(height: 16),
          stats,
        ],
      );
    }

    if (featuredCard == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SizedBox(height: 170, child: revenueCard)),
          const SizedBox(width: 24),
          Expanded(child: stats),
        ],
      );
    }

    return SizedBox(
      height: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: featuredCard),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: revenueCard),
                const SizedBox(height: 16),
                SizedBox(height: 104, child: stats),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.featured,
    required this.tall,
    required this.onManage,
    required this.onScan,
  });

  final _Featured featured;
  final bool tall;
  final VoidCallback onManage;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final e = featured.event;
    final total = e.ticketsTotal;
    final fraction = total == 0 ? 0.0 : (e.ticketsSold / total).clamp(0.0, 1.0);

    final progress = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tickets sold',
              style: orgText(p, size: 14, color: Colors.white70),
            ),
            Text(
              e.soldLabel,
              style: orgText(
                p,
                size: 14,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ProgressBar(
          fraction: fraction,
          track: Colors.white.withValues(alpha: 0.18),
          fill: Colors.white,
          height: 6,
        ),
      ],
    );

    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassButton(label: 'Manage', onTap: onManage),
        const SizedBox(width: 12),
        _WhiteScanButton(onTap: onScan),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  featured.label,
                  style: orgText(
                    p,
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (tall) const Spacer() else const SizedBox(height: 28),
          Text(
            e.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: orgText(
              p,
              size: 44,
              weight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_dateLabel(e)}  \u2022  ${e.venue}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: orgText(p, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          ),
          SizedBox(height: tall ? 28 : 24),
          if (tall)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 5, child: progress),
                const Spacer(flex: 1),
                buttons,
              ],
            )
          else ...[
            progress,
            const SizedBox(height: 16),
            buttons,
          ],
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: orgText(
              p,
              size: 15,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _WhiteScanButton extends StatelessWidget {
  const _WhiteScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 20,
                color: Color(0xFF4C1D95),
              ),
              const SizedBox(width: 10),
              Text(
                'Open Scanner',
                style: orgText(
                  p,
                  size: 15,
                  weight: FontWeight.w700,
                  color: const Color(0xFF4C1D95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.amount, required this.caption});

  final double amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerCard(
      radius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total revenue',
                style: orgText(p, size: 15, color: p.textSecondary),
              ),
              Text(
                caption,
                style: orgText(p, size: 14, color: p.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\u20B1${_money(amount)}',
              style: orgText(
                p,
                size: 52,
                weight: FontWeight.w800,
                color: p.success,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: p.isDark ? 0.28 : 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: p.accentLabel),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 14, color: p.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(
                    p,
                    size: 30,
                    weight: FontWeight.w800,
                    height: 1.1,
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.fraction,
    required this.track,
    required this.fill,
    this.height = 6,
  });

  final double fraction;
  final Color track;
  final Color fill;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth * fraction;
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(height),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            // A sold-out-of-nothing bar still shows a small dot, like the design.
            width: w < height ? height : w,
            height: height,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// My Events
// ---------------------------------------------------------------------------

class _MyEventsSection extends StatelessWidget {
  const _MyEventsSection({
    required this.events,
    required this.onViewAll,
    required this.onManage,
    required this.onScan,
    required this.onCancel,
  });

  final List<OrganizerEvent> events;
  final VoidCallback onViewAll;
  final void Function(OrganizerEvent) onManage;
  final void Function(OrganizerEvent) onScan;
  final void Function(OrganizerEvent) onCancel;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final shown = events.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Events',
              style: orgText(p, size: 24, weight: FontWeight.w800),
            ),
            if (events.isNotEmpty)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all (${events.length})',
                        style: orgText(
                          p,
                          size: 15,
                          weight: FontWeight.w700,
                          color: p.accentLabel,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: p.accentLabel,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (events.isEmpty)
          OrganizerCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              children: [
                Icon(Icons.event_note_outlined, size: 40, color: p.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'No events yet. Create your first event to get started.',
                  textAlign: TextAlign.center,
                  style: orgText(p, size: 14, color: p.textSecondary),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1000
                  ? 4
                  : (c.maxWidth >= 640 ? 2 : 1);
              const gap = 24.0;
              final cardWidth = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final e in shown)
                    SizedBox(
                      width: cardWidth,
                      child: _EventCard(
                        event: e,
                        onManage: () => onManage(e),
                        onScan: () => onScan(e),
                        onCancel: () => onCancel(e),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onManage,
    required this.onScan,
    required this.onCancel,
  });

  final OrganizerEvent event;
  final VoidCallback onManage;
  final VoidCallback onScan;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final e = event;
    final published = e.status == EventStatus.published;
    final cancelled = e.status == EventStatus.cancelled;
    final total = e.ticketsTotal;
    final fraction = total == 0 ? 0.0 : (e.ticketsSold / total).clamp(0.0, 1.0);
    final bannerUrl = EventRepository.instance.publicBannerUrl(e.bannerUrl);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: p.isDark
            ? null
            : [
                BoxShadow(
                  color: p.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6D35D8), Color(0xFF2A1366)],
                    ),
                  ),
                ),
                if (bannerUrl != null)
                  Image.network(
                    bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: p.isDark
                          ? p.background.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      e.status.label,
                      style: orgText(
                        p,
                        size: 12,
                        weight: FontWeight.w700,
                        color: published
                            ? p.success
                            : (cancelled ? p.danger : p.textSecondary),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 19, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel(e),
                  style: orgText(p, size: 14, color: p.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: p.accentLabel,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: orgText(p, size: 14, color: p.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sold',
                      style: orgText(p, size: 13, color: p.textSecondary),
                    ),
                    Text(
                      e.soldLabel,
                      style: orgText(p, size: 13, weight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ProgressBar(
                  fraction: fraction,
                  track: p.progressTrack,
                  fill: p.accentLabel,
                  height: 5,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _SmallGradientButton(label: 'Manage', onTap: onManage),
                    if (published) ...[
                      const SizedBox(width: 10),
                      _SquareIconButton(
                        icon: Icons.qr_code_scanner_rounded,
                        onTap: onScan,
                      ),
                    ],
                    const Spacer(),
                    MouseRegion(
                      cursor: cancelled
                          ? SystemMouseCursors.forbidden
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: cancelled ? null : onCancel,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: Text(
                            'Cancel',
                            style: orgText(
                              p,
                              size: 14,
                              weight: FontWeight.w700,
                              color: cancelled
                                  ? p.textSecondary.withValues(alpha: 0.5)
                                  : p.danger,
                            ),
                          ),
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
    );
  }
}

class _SmallGradientButton extends StatelessWidget {
  const _SmallGradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        height: 40,
        decoration: BoxDecoration(
          gradient: FairTixPalette.buttonGradient,
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: orgText(
                  p,
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);

    return Tooltip(
      message: 'Open scanner',
      child: Material(
        color: p.primary.withValues(alpha: p.isDark ? 0.28 : 0.10),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: p.accentLabel),
          ),
        ),
      ),
    );
  }
}
