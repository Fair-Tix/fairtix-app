import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/event.dart';
import 'ft_dark_ui.dart';
import 'ft_dashboard_ui.dart' show FtPressScale;

/// Shared ticket-card look used by My Tickets, the Resale Market listings and
/// My Listed Tickets, so a ticket reads the same everywhere. Geometry is
/// fixed: poster, a details row, a perforation line with a notch at each
/// edge, and a footer with a left slot and an optional action button.
const double kFtPosterHeight = 132;
const double kFtInfoHeight = 62;
const double kFtFooterHeight = 60;
const double _kNotchY = kFtPosterHeight + kFtInfoHeight;
const double _kNotchRadius = 10;
const double kFtCardRadius = 20;

/// Draws the ticket-shaped card: rounded rectangle with a half-circle bite
/// out of each side at the perforation, a border around that shape, and the
/// dashed line between the notches.
class FtTicketShapePainter extends CustomPainter {
  FtTicketShapePainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(kFtCardRadius)));
    final bites = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0, _kNotchY), radius: _kNotchRadius))
      ..addOval(Rect.fromCircle(center: Offset(size.width, _kNotchY), radius: _kNotchRadius));
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
        Offset(x, _kNotchY),
        Offset((x + 5).clamp(0, end).toDouble(), _kNotchY),
        dash,
      );
      x += 9;
    }
  }

  @override
  bool shouldRepaint(FtTicketShapePainter old) => old.fill != fill || old.border != border;
}

/// Event artwork: the organizer's banner when there is one, otherwise the
/// event's accent color with its initials. The accent color also shows while
/// the image loads and if it fails to load (e.g. offline).
class FtEventArt extends StatelessWidget {
  const FtEventArt({super.key, required this.event, this.initialsSize = 40});

  final EventSummary event;
  final double initialsSize;

  String get _initials {
    final words =
        event.title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    String first(String w) => String.fromCharCode(w.runes.first);
    final letters = words.length > 1 ? first(words[0]) + first(words[1]) : first(words[0]);
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = event.bannerUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: event.accentColor),
        Center(
          child: Text(
            _initials,
            style: GoogleFonts.plusJakartaSans(
              fontSize: initialsSize,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
        if (url != null)
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const SizedBox.shrink(),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// Small dark pill drawn over the poster (status, tier). It stays dark in
/// both themes so it is readable on any banner.
class FtOverlayChip extends StatelessWidget {
  const FtOverlayChip({super.key, required this.label, this.dotColor});

  final String label;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, height: 1.2, color: t.secondaryText),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: t.titleColor,
          ),
        ),
      ],
    );
  }
}

/// Button used in the card footer. With no [onTap] (or [enabled] false) it is
/// only a visual, e.g. "View ticket" on a card that is tappable as a whole.
class FtTicketButton extends StatelessWidget {
  const FtTicketButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
    this.outlined = false,
    this.color,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;

  /// Outlined (text in [color]) instead of filled.
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final base = color ?? FtColors.progressStart;
    final fg = outlined ? base : Colors.white;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ],
    );
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (enabled ? base : t.progressTrack),
        border: outlined ? Border.all(color: base.withValues(alpha: 0.7)) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: content,
    );
    final tappable = enabled && onTap != null;
    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: label,
      excludeSemantics: onTap != null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: tappable
            ? Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: box,
                ),
              )
            : box,
      ),
    );
  }
}

/// Poster ticket card. Fill the footer through [footer] (left side) and
/// [action] (right side). Give [onTap] to make the whole card tappable.
class FtTicketCard extends StatelessWidget {
  const FtTicketCard({
    super.key,
    required this.event,
    required this.tierName,
    required this.seatingLabel,
    required this.chipLabel,
    required this.chipColor,
    required this.footer,
    required this.semanticLabel,
    this.action,
    this.onTap,
    this.actionIsInteractive = false,
  });

  final EventSummary event;
  final String tierName;
  final String seatingLabel;

  /// Status text and dot color shown top-left on the poster.
  final String chipLabel;
  final Color chipColor;

  final Widget footer;
  final Widget? action;
  final VoidCallback? onTap;
  final String semanticLabel;

  /// True when [action] is its own button (the card's semantics then keep it
  /// reachable instead of hiding it).
  final bool actionIsInteractive;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);

    final card = CustomPaint(
      painter: FtTicketShapePainter(
        fill: t.isDark ? t.surfaceFill.withValues(alpha: 0.8) : t.surfaceFill,
        border: t.surfaceBorder,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(kFtCardRadius)),
            child: SizedBox(
              height: kFtPosterHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FtEventArt(event: event),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                        ),
                      ),
                      child: Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: FtOverlayChip(label: chipLabel, dotColor: chipColor),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: FtOverlayChip(label: tierName),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: kFtInfoHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(flex: 5, child: _InfoColumn(label: 'Date', value: event.dayLabel)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _InfoColumn(label: 'Time', value: event.timeLabel ?? '\u2014'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: _InfoColumn(label: 'Seating', value: seatingLabel)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: kFtFooterHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(child: footer),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(container: true, label: semanticLabel, child: card);
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: !actionIsInteractive,
      child: FtPressScale(onTap: onTap!, child: card),
    );
  }
}
