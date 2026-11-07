import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/resale_repository.dart';
import '../../services/ticket_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/ft_subpage_ui.dart';
import '../../widgets/ft_transaction_ui.dart' show formatPesoShort;
import 'resale_confirmation_screen.dart';

/// "List for resale" screen — lets the ticket owner set a resale price,
/// enforcing FairTix's system-wide resale band: the price must fall
/// between 50% (floor, to prevent nominal-price transfers that bypass
/// purchase limits) and 100% (ceiling, to prevent scalping) of the
/// ticket's original purchase price.
///
/// The price is picked with a slider or one of four quick amounts, so it can
/// never leave the allowed band. The server checks the band again anyway.
class ResaleListingScreen extends StatefulWidget {
  const ResaleListingScreen({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<ResaleListingScreen> createState() => _ResaleListingScreenState();
}

class _ResaleListingScreenState extends State<ResaleListingScreen> {
  bool _isSubmitting = false;
  late double _price;

  double get _minPrice => widget.ticket.minResalePrice;
  double get _maxPrice => widget.ticket.maxResalePrice;
  bool get _windowClosed => widget.ticket.event.isResaleWindowClosed;
  bool get _hasRange => _maxPrice > _minPrice;

  /// Four evenly spaced prices from the floor to the ceiling.
  List<double> get _quickPrices => [
        for (var i = 0; i < 4; i++)
          (_minPrice + (_maxPrice - _minPrice) * i / 3).roundToDouble().clamp(_minPrice, _maxPrice).toDouble(),
      ];

  /// FairTix's flat resale fee, taken from the seller's side (the server
  /// rounds the same way: c_resale_fee_rate in supabase/resale_purchase.sql).
  double get _fee => (_price * kResaleSellerFeeRate * 100).round() / 100;
  double get _receive => _price - _fee;

  bool get _isValid => !_windowClosed && _price > 0 && _price >= _minPrice && _price <= _maxPrice;

  @override
  void initState() {
    super.initState();
    _price = _hasRange ? _quickPrices[2] : _maxPrice;
  }

  void _setPrice(double value) {
    setState(() => _price = value.roundToDouble().clamp(_minPrice, _maxPrice).toDouble());
  }

  Future<void> _handleListTicket() async {
    if (!_isValid || _isSubmitting) return;
    final price = _price;
    setState(() => _isSubmitting = true);

    try {
      await ResaleRepository.instance.listTicket(ticketId: widget.ticket.id, price: price);
    } on ResaleException catch (e) {
      // Nothing was listed, so don't show the confirmation — stay here and
      // say why (e.g. window closed, price out of range).
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    // The listing now exists in the database. Reload the wallet so the
    // ticket shows as "listed" everywhere. If the reload itself fails the
    // listing is still real, so fall back to a locally updated copy.
    try {
      await TicketRepository.instance.refresh();
    } on TicketRepositoryException {
      // Ignored on purpose; see above.
    }
    if (!mounted) return;

    final refreshed = TicketRepository.instance.getById(widget.ticket.id);
    final listedTicket = (refreshed != null && refreshed.status == TicketStatus.listed)
        ? refreshed
        : widget.ticket.copyWith(status: TicketStatus.listed, resalePrice: price);

    setState(() => _isSubmitting = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResaleConfirmationScreen(ticket: listedTicket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final ticket = widget.ticket;
    final event = ticket.event;
    final interactive = !_windowClosed && _hasRange && !_isSubmitting;

    return FtSubpageScaffold(
      title: 'List for resale',
      titleAtEnd: true,
      onBack: () => Navigator.of(context).maybePop(),
      followTheme: true,
      bottomButton: FtGradientButton(
        label: _isValid ? 'List for ${formatPesoShort(_price)}' : 'List for resale',
        loading: _isSubmitting,
        onPressed: _isValid ? _handleListTicket : null,
      ),
      body: [
        if (_windowClosed) ...[
          const FtBanner(
            message:
                'Resale listings for this event have closed. Listings automatically close 24 hours before the event starts.',
          ),
          const SizedBox(height: 16),
        ],
        FtSurfaceCard(
          padding: const EdgeInsets.all(16),
          radius: 22,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FairTixPalette.buttonGradient,
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: t.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.tier.name} • ${event.dateLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: t.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Face value',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: t.subtitleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPesoShort(ticket.originalPrice),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t.titleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            'Your asking price',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: t.subtitleColor),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Center(
            child: Text(
              formatPesoShort(_price),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 46,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: t.titleColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_hasRange) ...[
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              activeTrackColor: FtColors.fieldBorderFocused,
              inactiveTrackColor: t.progressTrack,
              disabledActiveTrackColor: FtColors.fieldBorderFocused.withValues(alpha: 0.5),
              disabledInactiveTrackColor: t.progressTrack,
              thumbShape: const _RingThumbShape(ring: FtColors.glow),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              min: _minPrice,
              max: _maxPrice,
              value: _price.clamp(_minPrice, _maxPrice).toDouble(),
              semanticFormatterCallback: (v) => formatPesoShort(v.roundToDouble()),
              onChanged: interactive ? _setPrice : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatPesoShort(_minPrice)} min',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: t.subtitleColor),
                ),
                Text(
                  '${formatPesoShort(_maxPrice)} max',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: t.subtitleColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _QuickPriceChip(
                    amount: _quickPrices[i],
                    selected: (_price - _quickPrices[i]).abs() < 0.5,
                    onTap: interactive ? () => _setPrice(_quickPrices[i]) : null,
                  ),
                ),
              ],
            ],
          ),
        ] else if (!_windowClosed)
          const FtBanner(message: 'Free tickets can’t be listed for resale.'),
        const SizedBox(height: 22),
        FtSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          radius: 22,
          child: Column(
            children: [
              FtSummaryRow(label: 'Listing price', value: formatPesoShort(_price)),
              const SizedBox(height: 14),
              FtSummaryRow(
                label: 'Resale fee (${(kResaleSellerFeeRate * 100).round()}%)',
                value: '−${formatPesoShort(_fee)}',
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: t.divider),
              const SizedBox(height: 16),
              FtSummaryRow(
                label: 'You receive',
                value: formatPesoShort(_receive),
                valueColor: t.success,
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FtNote(
          icon: Icons.schedule_rounded,
          text: _windowClosed
              ? 'This event has already reached its resale cutoff.'
              : 'Closes ${formatClosesAt(event.resaleListingCloseTime)}. Paid out after the buyer gets their new QR.',
        ),
      ],
    );
  }
}

/// One of the four quick price buttons under the slider.
class _QuickPriceChip extends StatelessWidget {
  const _QuickPriceChip({required this.amount, required this.selected, required this.onTap});

  final double amount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final radius = BorderRadius.circular(28);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Set price to ${formatPesoShort(amount)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected ? FairTixPalette.buttonGradient : null,
          color: selected ? null : t.surfaceFill,
          border: selected ? null : Border.all(color: t.surfaceBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatPesoShort(amount),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : t.secondaryText,
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

/// Slider knob: a white disc with a purple ring around it.
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.ring});

  final Color ring;

  static const double _outer = 14;
  static const double _inner = 10;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_outer);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _outer, Paint()..color = ring);
    canvas.drawCircle(center, _inner, Paint()..color = Colors.white);
  }
}
