import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import '../../services/organizer_escrow_service.dart';
import '../../services/organizer_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_event_widgets.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-scaffold.dart';
import 'widgets/organizer_export_button.dart';

/// Organizer > Analytics (Mahilum design): four summary cards, then one card
/// per event with a tier table (price, sold, remaining, gross, your net).
///
/// Loads fresh data on open, then keeps itself current: a Supabase realtime
/// listener on `ticket_tiers` refreshes after every purchase/refund, with a
/// 20-second poll as a safety net (e.g. if realtime isn't enabled on the
/// table). Per-tier sold / remaining / revenue come from
/// `ticket_tiers.total_quantity - remaining_quantity`, which
/// `_do_ticket_purchase` decrements on each sale.
///
/// Refunds, and the platform fee that turns gross into "your net", come from
/// the same escrow overview the Escrow & Payouts screen reads, so the summary
/// cards always agree with it and with the Dashboard. The per-tier rows come
/// from `organizer_tier_sales` (supabase/organizer_escrow.sql): tickets sold
/// net of refunds, with the gross and fee actually charged on each purchase.
/// If that function is not installed yet, the tier rows fall back to the
/// inventory counts below.
class OrganizerAnalyticsSalesScreen extends StatefulWidget {
  const OrganizerAnalyticsSalesScreen({super.key});

  @override
  State<OrganizerAnalyticsSalesScreen> createState() =>
      _OrganizerAnalyticsSalesScreenState();
}

class _OrganizerAnalyticsSalesScreenState
    extends State<OrganizerAnalyticsSalesScreen> {
  bool _isLoading = true;
  String? _loadError;
  VoidCallback? _stopListening;
  Timer? _poll;

  /// Escrow rows by event id (refunds and fees). Empty if they could not be
  /// loaded, in which case refunds show as unknown and fees fall back to the
  /// organizer's plan rate.
  Map<String, EscrowEventRow> _escrow = const {};
  bool _escrowLoaded = false;
  EscrowOverview? _overview;

  /// Real per-tier sales, or null when `organizer_tier_sales` is unavailable.
  Map<String, TierSalesRow>? _tierSales;

  @override
  void initState() {
    super.initState();
    _load();
    try {
      _stopListening = EventRepository.instance.listenForSales(_silentReload);
    } catch (_) {
      // Realtime unavailable - the poll below still keeps the numbers fresh.
    }
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _silentReload());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _stopListening?.call();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException catch (e) {
      _loadError = e.message;
    }
    await _loadEscrow();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadEscrow() async {
    try {
      final overview = await OrganizerEscrowService.instance.fetch();
      _overview = overview;
      _escrow = {for (final r in overview.events) r.eventId: r};
      _escrowLoaded = true;
    } catch (_) {
      // Keep whatever we had; the screen still works without it.
    }
    final tiers = await OrganizerEscrowService.instance.fetchTierSales();
    if (tiers != null) _tierSales = tiers;
  }

  Future<void> _silentReload() async {
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException {
      return;
    }
    // Sold / gross / net / refunds are read from the database, so they are
    // refreshed together with the event list.
    await _loadEscrow();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerScaffold(
      pageTitle: 'Analytics',
      activeItem: OrganizerNavItem.analytics,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(p),
          const SizedBox(height: 24),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: p.accentLabel,
                ),
              ),
            )
          else if (_loadError != null)
            _errorState(p, _loadError!)
          else
            ..._content(p),
        ],
      ),
    );
  }

  Widget _header(FairTixPalette p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
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
                'Sales, revenue and inventory across your events.',
                style: orgText(p, size: 15, color: p.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Figures cover every event; there is no date filter yet.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          child: Text(
            'All time',
            style: orgText(p, size: 13, weight: FontWeight.w600, height: 1.2),
          ),
        ),
        const SizedBox(width: 8),
        // Downloads the revenue report straight away (CSV or PDF) instead of
        // opening a separate report page.
        const OrganizerExportButton(),
      ],
    );
  }

  List<Widget> _content(FairTixPalette p) {
    final events = EventRepository.instance.events;
    final feeFallback = OrganizerSession.instance.account?.subscriptionFeeRate;
    final sales = [
      for (final e in events)
        _EventSales.from(e, _escrow[e.id], feeFallback, _tierSales),
    ];

    // Summary cards: the escrow overview's totals when available (the same
    // numbers as Escrow & Payouts and the Dashboard); otherwise the sum of
    // the tier rows.
    final overview = _overview;
    var soldTotal = 0;
    var grossTotal = 0.0;
    double? netTotal = 0.0;
    if (overview != null) {
      soldTotal = overview.totalTicketsSold;
      grossTotal = overview.totalGross;
      netTotal = overview.totalNet;
    } else {
      for (final s in sales) {
        soldTotal += s.sold;
        grossTotal += s.gross;
        final n = s.net;
        if (n == null) {
          netTotal = null;
        } else if (netTotal != null) {
          netTotal += n;
        }
      }
    }

    final refundedTickets = _escrow.values.fold<int>(
      0,
      (sum, r) => sum + r.refundedTickets,
    );
    final refundedAmount = _escrow.values.fold<double>(
      0,
      (sum, r) => sum + r.refunded,
    );

    return [
      OrganizerStatGrid(
        children: [
          _StatCard(
            icon: Icons.confirmation_number_outlined,
            label: 'Tickets sold',
            value: '$soldTotal',
            note: 'Net of refunds',
          ),
          _StatCard(
            icon: Icons.monetization_on_outlined,
            label: 'Gross sales',
            value: organizerPeso(grossTotal),
            note: 'Before platform fee',
          ),
          _StatCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Your net share',
            value: netTotal == null ? '\u2014' : organizerPeso(netTotal),
            valueColor: p.success,
            note: 'After FairTix fee',
          ),
          _StatCard(
            icon: Icons.undo_rounded,
            label: 'Refunded',
            value: _escrowLoaded ? organizerPeso(refundedAmount) : '\u2014',
            valueColor: _yellow(p),
            note: !_escrowLoaded
                ? 'Refunds unavailable'
                : refundedTickets == 0
                ? 'No refunds'
                : '$refundedTickets ticket${refundedTickets == 1 ? '' : 's'}'
                      ' \u00B7 canceled events',
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text('Sales by event', style: orgText(p, size: 18, weight: FontWeight.w800)),
      const SizedBox(height: 14),
      if (sales.isEmpty)
        OrganizerCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Center(
            child: Text(
              'No events yet. Create an event to see sales here.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
          ),
        )
      else
        for (final s in sales) ...[
          _EventSalesCard(sales: s),
          const SizedBox(height: 18),
        ],
      Text(
        'Gross is the ticket price. Your net is the price minus FairTix\u2019s '
        'platform fee, the same amount shown in Escrow & Payouts. Refunded '
        'tickets are excluded from sold and revenue.',
        style: orgText(p, size: 13, color: p.textSecondary, height: 1.5),
      ),
    ];
  }

  Widget _errorState(FairTixPalette p, String message) {
    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: orgText(p, size: 14, color: p.danger),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 160,
            child: OrganizerSecondaryButton(
              label: 'Retry',
              height: 44,
              onPressed: _load,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow used for money that went back to buyers (design); amber in Light.
Color _yellow(FairTixPalette p) =>
    p.isDark ? const Color(0xFFFACC15) : p.warning;

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

class _TierSales {
  const _TierSales({
    required this.tier,
    required this.sold,
    required this.gross,
    required this.net,
  });

  final TicketTier tier;

  /// Tickets sold net of refunds.
  final int sold;
  final double gross;

  /// Null when the platform fee is unknown (no escrow data and no plan).
  final double? net;
}

class _EventSales {
  const _EventSales({
    required this.event,
    required this.escrow,
    required this.tiers,
  });

  final OrganizerEvent event;
  final EscrowEventRow? escrow;
  final List<_TierSales> tiers;

  int get sold => tiers.fold(0, (sum, t) => sum + t.sold);
  double get gross => tiers.fold(0.0, (sum, t) => sum + t.gross);

  double? get net {
    var total = 0.0;
    for (final t in tiers) {
      final n = t.net;
      if (n == null) return null;
      total += n;
    }
    return total;
  }

  factory _EventSales.from(
    OrganizerEvent e,
    EscrowEventRow? r,
    double? feeFallback,
    Map<String, TierSalesRow>? tierSales,
  ) {
    final refunded = r?.refundedTickets ?? 0;

    // The fee actually charged on this event's sales, as a fraction of gross.
    final double? fee = (r != null && r.gross > 0) ? r.fees / r.gross : feeFallback;

    return _EventSales(
      event: e,
      escrow: r,
      tiers: [
        for (final t in e.tiers)
          () {
            // Preferred: the real per-tier figures. Refunded tickets are
            // already left out, and gross / net use the amounts and fees
            // actually charged. A tier with no purchases has no row.
            if (tierSales != null) {
              final row = tierSales[TierSalesRow.keyFor(e.id, t.name)];
              return _TierSales(
                tier: t,
                sold: row?.sold ?? 0,
                gross: row?.gross ?? 0,
                net: row?.net ?? 0,
              );
            }

            // Fallback (organizer_tier_sales not installed): refunds are only
            // known per event. With a single tier of a single-day event they
            // can be taken off it exactly. Multi-day runs already leave
            // canceled days out of the tier roll-up, so nothing more is
            // deducted there; with several tiers the figures stay as sold.
            final sold = e.tiers.length == 1 && !e.isMultiDay && refunded > 0
                ? (t.sold - refunded).clamp(0, t.quantity).toInt()
                : t.sold;
            final gross = sold * t.price;
            final net = gross == 0 ? 0.0 : (fee == null ? null : gross * (1 - fee));
            return _TierSales(tier: t, sold: sold, gross: gross, net: net);
          }(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

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

class _EventSalesCard extends StatelessWidget {
  const _EventSalesCard({required this.sales});

  final _EventSales sales;

  static const _headers = ['TIER', 'PRICE', 'SOLD', 'REMAINING', 'GROSS', 'YOUR NET'];

  /// Column widths, matching the design. The last two are right-aligned.
  static const _flex = [12, 15, 30, 25, 18, 20];

  /// Below this width the table scrolls sideways instead of squeezing.
  static const double _minWidth = 760;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final e = sales.event;
    final bannerUrl = EventRepository.instance.publicBannerUrl(e.bannerUrl);

    var date = OrganizerEvent.formatDateRange(e.date, e.date, false);
    if (e.isMultiDay && e.dayCount > 0) {
      date = '$date  \u00B7  ${e.dayCount} day${e.dayCount == 1 ? '' : 's'}';
    }

    return OrganizerCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Row(
                children: [
                  OrganizerEventAvatar(
                    event: e,
                    bannerUrl: bannerUrl,
                    width: 44,
                    height: 44,
                    radius: 12,
                    fontSize: 14,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: orgText(
                            p,
                            size: 17,
                            weight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          date,
                          style: orgText(
                            p,
                            size: 14,
                            color: p.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OrganizerStatusChip(event: e),
                ],
              ),
            ),
            if (sales.tiers.isEmpty)
              Container(
                color: _band(p),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Text(
                  'No ticket tiers yet.',
                  style: orgText(p, size: 14, color: p.textSecondary),
                ),
              )
            else
              _table(p),
            _refundNote(p),
          ],
        ),
      ),
    );
  }

  Color _band(FairTixPalette p) =>
      p.primary.withValues(alpha: p.isDark ? 0.08 : 0.05);

  Widget _table(FairTixPalette p) {
    final e = sales.event;
    final live = e.status == EventStatus.published;

    Widget row(List<Widget> cells, {Color? color, Border? border}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: color, border: border),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: _flex[i],
                child: Align(
                  alignment: i >= 4
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: cells[i],
                ),
              ),
          ],
        ),
      );
    }

    final body = orgText(p, size: 14, height: 1.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrolls = constraints.maxWidth < _minWidth;
        final table = SizedBox(
          width: scrolls ? _minWidth : constraints.maxWidth,
          child: Column(
            children: [
              row(
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
                color: _band(p),
              ),
              for (final t in sales.tiers)
                row(
                  [
                    Text(
                      t.tier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: orgText(p, size: 14, weight: FontWeight.w600, height: 1.3),
                    ),
                    Text(organizerPeso(t.tier.price), style: body),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${t.sold} / ${t.tier.quantity}', style: body),
                        const SizedBox(width: 12),
                        OrganizerProgressBar(
                          ratio: t.tier.quantity > 0
                              ? t.sold / t.tier.quantity
                              : 0,
                          width: 90,
                        ),
                      ],
                    ),
                    _remaining(p, t, live),
                    Text(organizerPeso(t.gross), style: body),
                    Text(
                      t.net == null
                          ? '\u2014'
                          : organizerPeso(t.net!, decimals: 2),
                      style: orgText(
                        p,
                        size: 14,
                        weight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                  border: Border(top: BorderSide(color: p.border)),
                ),
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
    );
  }

  Widget _remaining(FairTixPalette p, _TierSales t, bool live) {
    if (!live) {
      return Text(
        '\u2014',
        style: orgText(p, size: 14, color: p.textSecondary, height: 1.3),
      );
    }
    final left = t.tier.quantity - t.sold;
    return Text(
      '$left',
      style: orgText(
        p,
        size: 14,
        weight: left == 0 ? FontWeight.w700 : FontWeight.w400,
        color: left == 0 ? p.danger : null,
        height: 1.3,
      ),
    );
  }

  Widget _refundNote(FairTixPalette p) {
    final r = sales.escrow;
    if (r == null || r.refundedTickets <= 0) return const SizedBox.shrink();

    final n = r.refundedTickets;
    final amount = r.refunded;
    final amountText = organizerPeso(
      amount,
      decimals: amount == amount.roundToDouble() ? 0 : 2,
    );
    final reason = sales.event.status == EventStatus.cancelled
        ? 'because the event was canceled.'
        : 'after the event was unpublished.';
    final color = _yellow(p);

    return Container(
      color: p.warningSurface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.undo_rounded, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$n ticket${n == 1 ? '' : 's'} refunded ($amountText) $reason',
              style: orgText(p, size: 13.5, color: color, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
