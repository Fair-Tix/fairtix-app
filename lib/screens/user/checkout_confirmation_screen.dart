import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../navigation/app_nav.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtPerforation;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import '../../widgets/ft_verified_ui.dart' show FtVerifiedCircle;
import 'ticket_detail_screen.dart';

/// Shown right after a successful purchase ("Ticket purchased"). Follows the
/// Light / Dark switch, with the same animated check as the "You're verified"
/// screen.
class CheckoutConfirmationScreen extends StatefulWidget {
  const CheckoutConfirmationScreen({
    super.key,
    required this.event,
    required this.tier,
    this.buyerEmail,
    this.purchasedTicket,
    this.paymentMethod,
  });

  final EventSummary event;
  final TicketTier tier;

  /// No longer shown on screen (the design doesn't mention the email), but
  /// kept so existing callers still compile.
  final String? buyerEmail;

  /// The ticket record created for this purchase, if the caller made one.
  /// When present, "View My Tickets" jumps straight to it instead of just
  /// landing on the My Tickets list.
  final Ticket? purchasedTicket;

  /// How the buyer paid, as PayMongo reports it ("gcash", "paymaya", "card"...).
  /// Null when unknown (or a free ticket); the receipt then says "Paid via PayMongo".
  final String? paymentMethod;

  @override
  State<CheckoutConfirmationScreen> createState() => _CheckoutConfirmationScreenState();
}

class _CheckoutConfirmationScreenState extends State<CheckoutConfirmationScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 1500;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _handleViewMyTicket(BuildContext context) {
    navigateToTab(context, 1);
    final ticket = widget.purchasedTicket;
    if (ticket != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final tier = widget.tier;
    final isFree = tier.price <= 0;
    final price = isFree ? 'Free' : formatPeso(tier.price).replaceAll('.00', '');

    final draw = _entrance.drive(
      CurveTween(
        curve: Interval(550 / _totalMs, 1000 / _totalMs, curve: Curves.easeInOut),
      ),
    );

    final t = FtAuthTheme.live(context);
    final p = FairTixPalette.of(context);
    // Dark keeps the original verified colors; Light uses the palette's.
    final Color? verifiedBg = t.isDark ? null : p.verifiedSurface;
    final Color? verifiedFg = t.isDark ? null : p.verified;

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
                    child: Column(
                      children: [
                        FtReveal(
                          animation: _entrance,
                          startMs: 100,
                          endMs: 550,
                          totalMs: _totalMs,
                          scaleFrom: 0.7,
                          child: FtVerifiedCircle(
                            draw: draw,
                            background: verifiedBg,
                            checkColor: verifiedFg,
                          ),
                        ),
                        const SizedBox(height: 26),
                        FtReveal(
                          animation: _entrance,
                          startMs: 650,
                          endMs: 1100,
                          totalMs: _totalMs,
                          slide: 12,
                          child: Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(
                              'Ticket purchased',
                              textAlign: TextAlign.center,
                              style: FtText.title().copyWith(
                                fontSize: 32,
                                letterSpacing: -0.5,
                                color: t.titleColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FtReveal(
                          animation: _entrance,
                          startMs: 780,
                          endMs: 1230,
                          totalMs: _totalMs,
                          slide: 8,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              'Your QR code is in My Tickets, tied to your verified account.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                height: 1.45,
                                color: t.secondaryText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        FtReveal(
                          animation: _entrance,
                          startMs: 900,
                          endMs: 1350,
                          totalMs: _totalMs,
                          slide: 16,
                          child: _ReceiptCard(
                            event: event,
                            tier: tier,
                            price: price,
                            isFree: isFree,
                            paymentMethod: widget.paymentMethod,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FtReveal(
                  animation: _entrance,
                  startMs: 1050,
                  endMs: 1500,
                  totalMs: _totalMs,
                  slide: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.bgBottom,
                      border: Border(top: BorderSide(color: t.surfaceBorder)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FtGradientButton(
                            label: 'View My Tickets',
                            onPressed: () => _handleViewMyTicket(context),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => navigateToTab(context, 0),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: Text(
                              'Back to Home',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Ticket-shaped receipt: the event on top, a perforation, then how it was paid.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.event,
    required this.tier,
    required this.price,
    required this.isFree,
    this.paymentMethod,
  });

  final EventSummary event;
  final TicketTier tier;
  final String price;
  final bool isFree;
  final String? paymentMethod;

  /// "Paid with GCash" when PayMongo told us the method, otherwise the
  /// generic "Paid via PayMongo".
  String get _paidLabel {
    final method = switch (paymentMethod?.toLowerCase()) {
      'gcash' => 'GCash',
      'paymaya' || 'maya' => 'Maya',
      'card' => 'card',
      'grab_pay' => 'GrabPay',
      _ => null,
    };
    return method == null ? 'Paid via PayMongo' : 'Paid with $method';
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Semantics(
      container: true,
      label: '${event.title}, ${tier.name}, ${event.dateLabel}, ${event.venue}. '
          '${isFree ? 'Free ticket' : '$_paidLabel, $price'}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: t.isDark ? t.surfaceFill.withValues(alpha: 0.8) : t.surfaceFill,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: t.surfaceBorder),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [FtColors.progressStart, FtColors.bgTop],
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: t.titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tier.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            height: 1.3,
                            color: t.secondaryText,
                          ),
                        ),
                        Text(
                          '${event.dateLabel} \u2022 ${event.venue}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            height: 1.3,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const FtPerforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isFree ? 'Free ticket' : _paidLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        height: 1.2,
                        color: t.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: t.titleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
