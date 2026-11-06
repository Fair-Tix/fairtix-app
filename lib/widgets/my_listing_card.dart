import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ticket.dart';
import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart';
import 'ft_resale_ui.dart' show formatClosesAt;
import 'ft_transaction_ui.dart' show formatPesoShort;

const double _kTopHeight = 112;
const double _kBottomHeight = 74;
const double _kNotchRadius = 13;

/// Card for the "My Listed Tickets" section of the Resale Market — one of
/// the current user's own tickets that's currently listed for resale. Shaped
/// like a ticket (a notch on each side of the dashed line), with the price
/// range on the left of the bottom strip and, when [onCancel] is given, a
/// "Cancel listing" action on the right.
class MyListingCard extends StatelessWidget {
  const MyListingCard({super.key, required this.ticket, required this.onTap, this.onCancel});

  final Ticket ticket;
  final VoidCallback onTap;

  /// Called when the seller taps "Cancel listing". Hidden when null.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final price = ticket.resalePrice ?? ticket.tier.price;
    final closesAt = ticket.event.resaleListingCloseTime;
    final isClosingSoon = closesAt.difference(DateTime.now()).inHours <= 24;
    final pillColor = isClosingSoon ? FairTixPalette.of(context).warning : t.success;
    final pillSurface = isClosingSoon ? FairTixPalette.of(context).warningSurface : t.successSurface;

    return Semantics(
      button: true,
      label: '${ticket.event.title}, ${ticket.tier.name}, listed at ${formatPesoShort(price)}, '
          '${isClosingSoon ? 'closing soon' : 'live'}. View details',
      excludeSemantics: true,
      child: CustomPaint(
        painter: _TicketShapePainter(
          fill: t.surfaceFill,
          border: Color.lerp(t.surfaceBorder, t.activeAccent, 0.55)!,
          dash: t.surfaceBorder,
        ),
        child: Column(
          children: [
            SizedBox(
              height: _kTopHeight,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: FairTixPalette.buttonGradient,
                          ),
                          child: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 30),
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: t.titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ticket.tier.name} • ${ticket.event.dateLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, color: t.subtitleColor),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 17, color: t.secondaryText),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Closes ${formatClosesAt(closesAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: isClosingSoon ? FontWeight.w700 : FontWeight.w400,
                                        color: isClosingSoon ? pillColor : t.subtitleColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatPesoShort(price),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: t.activeAccent,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: pillSurface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(color: pillColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isClosingSoon ? 'Closing soon' : 'Live',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: pillColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _kBottomHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Price range: 50%–100% of face value',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          height: 1.35,
                          color: t.subtitleColor,
                        ),
                      ),
                    ),
                    if (onCancel != null) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: t.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Cancel\nlisting',
                          textAlign: TextAlign.start,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: t.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ticket-shaped card: a rounded rectangle with a half-circle bite out of
/// each side at the perforation, a border around that shape, and a dashed line
/// between the notches.
class _TicketShapePainter extends CustomPainter {
  _TicketShapePainter({required this.fill, required this.border, required this.dash});

  final Color fill;
  final Color border;
  final Color dash;

  @override
  void paint(Canvas canvas, Size size) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)));
    final bites = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, _kTopHeight), radius: _kNotchRadius))
      ..addOval(Rect.fromCircle(center: Offset(size.width, _kTopHeight), radius: _kNotchRadius));
    final shape = Path.combine(PathOperation.difference, card, bites);

    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = border,
    );

    final line = Paint()
      ..color = dash
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    var x = _kNotchRadius + 14;
    final end = size.width - _kNotchRadius - 14;
    while (x < end) {
      canvas.drawLine(
        Offset(x, _kTopHeight),
        Offset((x + 6).clamp(0, end).toDouble(), _kTopHeight),
        line,
      );
      x += 11;
    }
  }

  @override
  bool shouldRepaint(_TicketShapePainter old) =>
      old.fill != fill || old.border != border || old.dash != dash;
}
