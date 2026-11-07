import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Shared building blocks for the dark Help, Notification, Resale and
/// confirmation screens. Everything draws with the [FtAuthTheme] handed down
/// by the surrounding scaffold, so it follows the Light / Dark switch.

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Oct 29, 12AM" (or "Oct 29, 9:30PM" when the time isn't on the hour).
String formatClosesAt(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute == 0 ? '' : ':${dt.minute.toString().padLeft(2, '0')}';
  return '${_monthNames[dt.month - 1]} ${dt.day}, $hour12$minute$period';
}

/// Rounded dark card used for every grouped block of content.
class FtSurfaceCard extends StatelessWidget {
  const FtSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: child,
    );
  }
}

/// Small spaced-out purple heading above a card ("CHANNELS", "PAY WITH").
class FtSectionLabel extends StatelessWidget {
  const FtSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: t.accent,
        ),
      ),
    );
  }
}

/// "Label ........ value" row used in price breakdowns.
class FtSummaryRow extends StatelessWidget {
  const FtSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// True for the bold total line at the bottom of a card.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: strong ? 17 : 15,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
              color: strong ? t.titleColor : t.subtitleColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: strong ? 20 : 15,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            color: valueColor ?? t.titleColor,
          ),
        ),
      ],
    );
  }
}

/// Icon + a sentence of quiet explanation under a card.
class FtNote extends StatelessWidget {
  const FtNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 19, color: t.secondaryText),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.4,
              color: t.subtitleColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen "it worked" layout: round icon, title, optional subtitle,
/// some content, and a bar at the bottom with a main button and an optional
/// text link. Used by "Your ticket is listed" and "Your ticket sold".
class FtResultScaffold extends StatelessWidget {
  const FtResultScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(19, 40, 19, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: t.successSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 34, color: t.success),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 27,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: t.titleColor,
                              ),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: t.subtitle().copyWith(fontSize: 15),
                            ),
                          ],
                          const SizedBox(height: 28),
                          ...body,
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.divider)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(19, 14, 19, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FtGradientButton(label: primaryLabel, onPressed: onPrimary),
                          if (secondaryLabel != null) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: onSecondary,
                              child: Text(
                                secondaryLabel!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: t.secondaryText,
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
          ),
        ),
      ),
    );
  }
}
