import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../../services/organizer_escrow_service.dart';
import 'organizer-scaffold.dart';

/// Organizer > Escrow & Payouts.
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
    return OrganizerScaffold(
      pageTitle: 'Escrow & Payouts',
      activeItem: OrganizerNavItem.escrow,
      topBarTrailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HowItWorks(),
          const SizedBox(height: 24),
          _content(),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }
    final overview = _overview;
    if (_error != null || overview == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Text(
              _error ?? 'Could not load escrow.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.dangerRed),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      );
    }

    final next = overview.nextRelease;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(
          cards: [
            _StatCard(
              icon: Icons.lock_outline,
              label: 'In escrow (held)',
              value: _peso(overview.totalHeld),
              note: next == null
                  ? 'Nothing is being held right now'
                  : 'Next release: ${_formatDate(next)}',
              valueColor: AppColors.warningOrange,
            ),
            _StatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Released to you',
              value: _peso(overview.totalReleased),
              note: 'Event over, ready for payout',
              valueColor: AppColors.successGreen,
            ),
            _StatCard(
              icon: Icons.undo_rounded,
              label: 'Refunded to buyers',
              value: _peso(overview.totalRefunded),
              note: 'From canceled events',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _eventsCard(overview),
        const SizedBox(height: 14),
        const Text(
          'Amounts are your share: the ticket price minus FairTix\'s platform '
          'fee. Scanning tickets at the door does not release escrow; money is '
          'released the day after your event\'s last day (Philippine time). '
          'Multi-day events release one day at a time as each day ends.',
          style: TextStyle(color: AppColors.textGray, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _eventsCard(EscrowOverview overview) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Escrow by Event', style: AppTextStyles.h3),
          ),
          if (overview.events.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 40,
                    color: AppColors.textGray,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No published events yet. Once a fan buys a ticket, the '
                    'payment appears here as held in escrow.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyGray,
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF9FAFB),
                ),
                columns: const [
                  DataColumn(label: Text('EVENT')),
                  DataColumn(label: Text('EVENT DATE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('TICKETS')),
                  DataColumn(label: Text('IN ESCROW')),
                  DataColumn(label: Text('RELEASED')),
                  DataColumn(label: Text('RELEASE DATE')),
                ],
                rows: [for (final e in overview.events) _eventRow(e)],
              ),
            ),
        ],
      ),
    );
  }

  DataRow _eventRow(EscrowEventRow e) {
    return DataRow(
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              e.title,
              style: AppTextStyles.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(_dateRange(e), style: AppTextStyles.body)),
        DataCell(_StageChip(stage: e.stage)),
        DataCell(Text('${e.ticketsSold}', style: AppTextStyles.body)),
        DataCell(
          Text(
            e.held > 0 ? _peso(e.held) : '\u2014',
            style: TextStyle(
              color: e.held > 0 ? AppColors.warningOrange : AppColors.textGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Text(
            e.released > 0 ? _peso(e.released) : '\u2014',
            style: TextStyle(
              color: e.released > 0
                  ? AppColors.successGreen
                  : AppColors.textGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(_releaseCell(e)),
      ],
    );
  }

  Widget _releaseCell(EscrowEventRow e) {
    final date = e.releaseDate;
    if (e.held > 0 && date != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDate(date), style: AppTextStyles.label),
          Text(
            _countdown(date),
            style: const TextStyle(color: AppColors.textGray, fontSize: 11),
          ),
        ],
      );
    }
    if (e.released > 0) {
      return const Text('Released', style: AppTextStyles.bodyGray);
    }
    return const Text('\u2014', style: AppTextStyles.bodyGray);
  }

  static BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.borderLight),
  );
}

// ── Explainer ──────────────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _FlowStep(
        number: 1,
        icon: Icons.shopping_cart_checkout_rounded,
        title: 'Fan buys a ticket',
        text: 'The buyer pays through PayMongo and receives their QR ticket.',
      ),
      _FlowStep(
        number: 2,
        icon: Icons.lock_outline,
        title: 'Held in escrow',
        text:
            'Your share (price minus FairTix\'s fee) is held while the event '
            'is still ahead or ongoing.',
      ),
      _FlowStep(
        number: 3,
        icon: Icons.event_available_outlined,
        title: 'Released to you',
        text:
            'Once your event\'s schedule date is over, the held amount is '
            'released for payout. If the event is canceled, buyers are '
            'refunded instead.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _OrganizerEscrowScreenState._cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How escrow works', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 760) {
                return Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      steps[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 14, 10, 0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textGray,
                        ),
                      ),
                    Expanded(child: steps[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String text;

  const _FlowStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primaryPurple, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number. $title', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                  height: 1.45,
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
  final List<_StatCard> cards;

  const _StatRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 760) {
          return Column(
            children: [
              for (final card in cards)
                Padding(padding: const EdgeInsets.only(bottom: 16), child: card),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color? valueColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _OrganizerEscrowScreenState._cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyGray, maxLines: 2),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.h2.copyWith(color: valueColor),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 11,
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

// ── Status chip ────────────────────────────────────────────────────────────

class _StageChip extends StatelessWidget {
  final EscrowStage stage;

  const _StageChip({required this.stage});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (stage) {
      EscrowStage.held => ('In escrow', AppColors.warningOrange),
      EscrowStage.partiallyReleased => (
        'Partly released',
        AppColors.primaryPurple,
      ),
      EscrowStage.released => ('Released', AppColors.successGreen),
      EscrowStage.refunded => ('Refunded', AppColors.dangerRed),
      EscrowStage.noSales => ('No sales', AppColors.textGray),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
