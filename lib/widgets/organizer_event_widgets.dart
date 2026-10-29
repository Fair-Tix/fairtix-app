import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/organizer_event.dart';
import '../theme/fairtix_palette.dart';
import 'organizer_ui.dart';

/// Small building blocks shared by the redesigned organizer My Events and
/// Analytics screens: event avatar, status chip, stat grid, progress bar.

/// "₱1,234" or "₱1,234.50" ([decimals] = 2).
String organizerPeso(double value, {int decimals = 0}) {
  final parts = value.toStringAsFixed(decimals).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return decimals == 0
      ? '\u20B1$whole'
      : '\u20B1$whole.${parts[1]}';
}

/// "Acquaintance Party" -> "AP", "Bruno Mark II" -> "BM".
String organizerInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// Rounded tile for an event: its banner when it has one, otherwise the
/// initials on a gradient (orange while live, purple otherwise).
class OrganizerEventAvatar extends StatelessWidget {
  const OrganizerEventAvatar({
    super.key,
    required this.event,
    this.bannerUrl,
    this.width = 72,
    this.height = 64,
    this.radius = 14,
    this.fontSize = 18,
  });

  final OrganizerEvent event;
  final String? bannerUrl;
  final double width;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final live = event.status == EventStatus.published;

    final List<Color> colors = live
        ? const [Color(0xFFF59E0B), Color(0xFFB45309)]
        : p.isDark
        ? const [Color(0xFF4A22A8), Color(0xFF2B1470)]
        : const [Color(0xFFE4DBFB), Color(0xFFD4C7F7)];
    final textColor = live
        ? Colors.white
        : (p.isDark ? p.accentLabel.withValues(alpha: 0.8) : p.accentLabel);

    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        organizerInitials(event.name),
        style: orgText(
          p,
          size: fontSize,
          weight: FontWeight.w800,
          color: textColor,
          height: 1,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: bannerUrl == null
            ? fallback
            : Image.network(
                bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Pill showing an event's status (Published, Completed, Cancelled, ...).
class OrganizerStatusChip extends StatelessWidget {
  const OrganizerStatusChip({super.key, required this.event});

  final OrganizerEvent event;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    final Color fg;
    final Color bg;
    final String label;
    if (event.isUnpublishedByAdmin) {
      label = 'Unpublished';
      fg = p.danger;
      bg = p.dangerSurface;
    } else {
      label = event.status.label;
      switch (event.status) {
        case EventStatus.published:
          fg = p.success;
          bg = p.successSurface;
          break;
        case EventStatus.cancelled:
          fg = p.danger;
          bg = p.dangerSurface;
          break;
        case EventStatus.draft:
          fg = p.warning;
          bg = p.warningSurface;
          break;
        case EventStatus.completed:
          fg = p.textSecondary;
          bg = p.progressTrack;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: orgText(
          p,
          size: 12,
          weight: FontWeight.w700,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Thin progress bar. Shows a sliver of fill for any non-zero [ratio] so a
/// first sale is still visible on a 500-ticket event.
class OrganizerProgressBar extends StatelessWidget {
  const OrganizerProgressBar({
    super.key,
    required this.ratio,
    this.width,
    this.height = 4,
  });

  final double ratio;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final r = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0).toDouble();

    final bar = SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.progressTrack)),
            if (r > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: math.max(r, 0.025),
                    child: ColoredBox(color: p.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return width == null ? bar : SizedBox(width: width, child: bar);
  }
}

/// Lays stat cards out 4-across on wide screens, 2x2 on medium and stacked
/// on narrow ones, with every card in a row the same height.
class OrganizerStatGrid extends StatelessWidget {
  const OrganizerStatGrid({super.key, required this.children, this.gap = 20});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1000
            ? children.length
            : (constraints.maxWidth >= 560 ? 2 : 1);

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.sublist(
            i,
            math.min(i + cols, children.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    Expanded(
                      child: j < slice.length
                          ? slice[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}
