import 'package:flutter/material.dart';

import '../../services/organizer_escrow_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-scaffold.dart';

/// Organizer > Escrow & Payouts (Mahilum design).
///
/// Shows the organizer exactly where their ticket money is:
///   buyer pays -> held in escrow -> released once the event's schedule date
///   is over (or refunded to buyers if the event is canceled).
///
/// Everything here is read from the database ([OrganizerEscrowService]); the
/// release itself happens server-side, never from this screen. Amounts are the
/// organizer's share: ticket price minus FairTix's platform fee.
class OrganizerEscrowScreen extends StatefulWidget {
  const OrganizerEscrowScreen({super.key});

  @override
  State<OrganizerEscrowScreen> createState() => _OrganizerEscrowScreenState();
}

class _OrganizerEscrowScreenState extends State<OrganizerEscrowScreen> {
  EscrowOverview? _overview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final overview = await OrganizerEscrowService.instance.fetch();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _error = null;
        _loading = false;
      });
    } on OrganizerEscrowException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load escrow. Please try again.';
        _loading = false;
      });
    }
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerScaffold(
      pageTitle: 'Escrow & Payouts',
      activeItem: OrganizerNavItem.escrow,
      topBarTrailing: _RefreshButton(onTap: _loading ? null : _refresh),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escrow & Payouts',
            style: orgText(
              p,
              size: 32,
              weight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track held funds, releases and refunds.',
            style: orgText(p, size: 15, color: p.textSecondary),
          ),
          const SizedBox(height: 24),
          const _HowItWorks(),
          const SizedBox(height: 20),
          _content(p),
        ],
      ),
    );
  }

  Widget _content(FairTixPalette p) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: p.accentLabel),
        ),
      );
    }

    final overview = _overview;
    if (_error != null || overview == null) {
      return OrganizerCard(
        radius: 20,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _error ?? 'Could not load escrow.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, color: p.danger),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 160,
              child: OrganizerSecondaryButton(
                label: 'Try again',
                height: 44,
                onPressed: _refresh,
              ),
            ),
          ],
        ),
      );
    }

    final next = overview.nextRelease;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatRow(
          cards: [
            _StatCard(
              icon: Icons.lock_outline_rounded,
              label: 'In escrow (held)',
              value: _peso(overview.totalHeld),
              note: next == null
                  ? 'Nothing is being held right now'
                  : 'Next release: ${_formatDate(next)}',
              valueColor: _heldColor(p),
            ),
            _StatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Released to you',
              value: _peso(overview.totalReleased),
              note: 'Event over, ready for payout',
              valueColor: p.success,
            ),
            _StatCard(
              icon: Icons.undo_rounded,
              label: 'Refunded to buyers',
              value: _peso(overview.totalRefunded),
              note: 'From canceled events',
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Escrow by Event',
          style: orgText(p, size: 18, weight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        _EventsTable(events: overview.events),
        const SizedBox(height: 14),
        Text(
          'Amounts are your share: the ticket price minus FairTix\u2019s '
          'platform fee. Scanning tickets at the door does not release '
          'escrow; money is released the day after your event\u2019s last '
          'day (Philippine time). Multi-day events release one day at a time '
          'as each day ends.',
          style: orgText(p, size: 13, color: p.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

/// Yellow used for held money (design), amber in Light mode for contrast.
Color _heldColor(FairTixPalette p) =>
    p.isDark ? const Color(0xFFFACC15) : p.warning;

// ── Top bar refresh button ─────────────────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Tooltip(
      message: 'Refresh',
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.surface,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: p.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Explainer ──────────────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    const steps = [
      _FlowStep(
        icon: Icons.shopping_cart_outlined,
        title: '1. Fan buys a ticket',
        text: 'The buyer pays through PayMongo and receives their QR ticket.',
      ),
      _FlowStep(
        icon: Icons.lock_outline_rounded,
        title: '2. Held in escrow',
        text:
            'Your share (price minus FairTix\u2019s fee) is held while the '
            'event is ahead or ongoing.',
      ),
      _FlowStep(
        icon: Icons.event_available_outlined,
        title: '3. Released to you',
        text:
            'Once your event\u2019s schedule date is over, the held amount is '
            'released for payout. If canceled, buyers are refunded instead.',
      ),
    ];

    final heading = Text(
      'How escrow works',
      style: orgText(p, size: 17, weight: FontWeight.w800, height: 1.3),
    );

    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 18),
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  steps[i],
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: heading,
                ),
              ),
              const SizedBox(width: 24),
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: p.textSecondary,
                    ),
                  ),
                Expanded(child: steps[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: p.primary.withValues(alpha: p.isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: p.accentLabel, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: orgText(p, size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: orgText(
                  p,
                  size: 13,
                  color: p.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stat cards ─────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({required this.cards});

  final List<_StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 760) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                cards[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 20),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: p.isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: p.accentLabel, size: 22),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 13, color: p.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(
                    p,
                    size: 32,
                    weight: FontWeight.w800,
                    color: valueColor,
                    letterSpacing: -0.6,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 13, color: p.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Escrow by event table ──────────────────────────────────────────────────

class _EventsTable extends StatelessWidget {
  const _EventsTable({required this.events});

  final List<EscrowEventRow> events;

  static const _headers = [
    'EVENT',
    'EVENT DATE',
    'STATUS',
    'TICKETS',
    'IN ESCROW',
    'RELEASED',
    'RELEASE DATE',
  ];

  /// Column widths, matching the design.
  static const _flex = [25, 19, 18, 14, 17, 16, 17];

  /// Below this width the table scrolls sideways instead of squeezing.
  static const double _minWidth = 980;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    if (events.isEmpty) {
      return OrganizerCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
        child: Column(
          children: [
            Icon(Icons.lock_clock_outlined, size: 40, color: p.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No published events yet. Once a fan buys a ticket, the '
              'payment appears here as held in escrow.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
          ],
        ),
      );
    }

    return OrganizerCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scrolls = constraints.maxWidth < _minWidth;
            final table = SizedBox(
              width: scrolls ? _minWidth : constraints.maxWidth,
              child: Column(
                children: [
                  _row(
                    [
                      for (final h in _headers)
                        Text(
                          h,
                          style: orgText(
                            p,
                            size: 11,
                            weight: FontWeight.w700,
                            color: p.textSecondary,
                            letterSpacing: 1.2,
                            height: 1.2,
                          ),
                        ),
                    ],
                    vertical: 18,
                  ),
                  for (final e in events) _eventRow(p, e),
                ],
              ),
            );
            return scrolls
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: table,
                  )
                : table;
          },
        ),
      ),
    );
  }

  Widget _row(
    List<Widget> cells, {
    double vertical = 20,
    Border? border,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
      decoration: BoxDecoration(border: border),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _flex[i],
              child: Align(alignment: Alignment.centerLeft, child: cells[i]),
            ),
        ],
      ),
    );
  }

  Widget _eventRow(FairTixPalette p, EscrowEventRow e) {
    final body = orgText(p, size: 14, height: 1.3);
    final dash = orgText(p, size: 14, color: p.textSecondary, height: 1.3);

    return _row(
      [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            e.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: orgText(p, size: 14, weight: FontWeight.w700, height: 1.3),
          ),
        ),
        Text(_dateRange(e), style: body),
        _StageChip(stage: e.stage),
        Text('${e.ticketsSold}', style: body),
        Text(
          e.held > 0 ? _peso(e.held) : '\u2014',
          style: e.held > 0
              ? orgText(
                  p,
                  size: 14,
                  weight: FontWeight.w700,
                  color: _heldColor(p),
                  height: 1.3,
                )
              : dash,
        ),
        Text(
          e.released > 0 ? _peso(e.released) : '\u2014',
          style: e.released > 0
              ? orgText(
                  p,
                  size: 14,
                  weight: FontWeight.w700,
                  color: p.success,
                  height: 1.3,
                )
              : dash,
        ),
        _releaseCell(p, e),
      ],
      border: Border(top: BorderSide(color: p.border)),
    );
  }

  Widget _releaseCell(FairTixPalette p, EscrowEventRow e) {
    final date = e.releaseDate;
    if (e.held > 0 && date != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(date),
            style: orgText(p, size: 14, weight: FontWeight.w600, height: 1.3),
          ),
          Text(
            _countdown(date),
            style: orgText(p, size: 12, color: p.textSecondary, height: 1.3),
          ),
        ],
      );
    }
    if (e.released > 0) {
      return Text(
        'Released',
        style: orgText(p, size: 14, color: p.textSecondary, height: 1.3),
      );
    }
    return Text(
      '\u2014',
      style: orgText(p, size: 14, color: p.textSecondary, height: 1.3),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final EscrowStage stage;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    final (label, color) = switch (stage) {
      EscrowStage.held => ('In escrow', _heldColor(p)),
      EscrowStage.partiallyReleased => ('Partly released', p.accentLabel),
      EscrowStage.released => ('Released', p.success),
      EscrowStage.refunded => ('Refunded', p.danger),
      EscrowStage.noSales => ('No sales', p.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: orgText(
          p,
          size: 12,
          weight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

// ── Formatting ─────────────────────────────────────────────────────────────

/// "₱1,234.50".
String _peso(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '\u20B1$whole.${parts[1]}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

String _dateRange(EscrowEventRow e) {
  final start = e.startDate;
  final end = e.endDate;
  if (start == null) return '\u2014';
  if (end == null || end == start) return _formatDate(start);
  return '${_formatDate(start)} \u2013 ${_formatDate(end)}';
}

/// "Tomorrow" / "In 5 days", counted in Philippine time like the release job.
String _countdown(DateTime releaseDate) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(
    releaseDate.year,
    releaseDate.month,
    releaseDate.day,
  ).difference(today).inDays;
  if (days <= 0) return 'Due now';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}
