import 'package:flutter/material.dart';

import '../theme/fairtix_palette.dart';
import 'organizer_ui.dart';

/// Small building blocks shared by the organizer account pages: Profile,
/// Subscription, Settings and Help & Support.

/// Page title with a one-line description underneath.
class OrganizerPageHeader extends StatelessWidget {
  const OrganizerPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: orgText(
            p,
            size: 32,
            weight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: orgText(p, size: 15, color: p.textSecondary)),
      ],
    );
  }
}

/// A titled card that groups related rows.
class OrganizerSectionCard extends StatelessWidget {
  const OrganizerSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return OrganizerCard(
      radius: 20,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: orgText(p, size: 18, weight: FontWeight.w800),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

enum OrganizerTone { success, warning, danger, neutral, accent }

({Color fg, Color bg}) organizerToneColors(FairTixPalette p, OrganizerTone t) {
  switch (t) {
    case OrganizerTone.success:
      return (fg: p.success, bg: p.successSurface);
    case OrganizerTone.warning:
      return (fg: p.warning, bg: p.warningSurface);
    case OrganizerTone.danger:
      return (fg: p.danger, bg: p.dangerSurface);
    case OrganizerTone.accent:
      return (
        fg: p.accentLabel,
        bg: p.primary.withValues(alpha: p.isDark ? 0.25 : 0.12),
      );
    case OrganizerTone.neutral:
      return (fg: p.textSecondary, bg: p.progressTrack);
  }
}

/// Rounded status pill ("Verified", "Active", "Submitted", ...).
class OrganizerPill extends StatelessWidget {
  const OrganizerPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final OrganizerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final c = organizerToneColors(p, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c.fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: orgText(
              p,
              size: 12.5,
              weight: FontWeight.w700,
              color: c.fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label above a value, with an optional lock icon for read-only fields.
class OrganizerDetailRow extends StatelessWidget {
  const OrganizerDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.locked = false,
  });

  final String label;
  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrganizerFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '\u2014' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orgText(p, size: 15, color: p.textSecondary),
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline_rounded, size: 18, color: p.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tappable row with an icon, title, optional subtitle and a chevron.
class OrganizerLinkRow extends StatelessWidget {
  const OrganizerLinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.topBorder = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: topBorder ? Border(top: BorderSide(color: p.border)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: p.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: p.accentLabel),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: orgText(p, size: 15, weight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: orgText(
                        p,
                        size: 13,
                        color: p.textSecondary,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Tinted callout used for guidance ("how to request a correction", ...).
class OrganizerNote extends StatelessWidget {
  const OrganizerNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.tone = OrganizerTone.accent,
    this.action,
  });

  final String text;
  final IconData icon;
  final OrganizerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final c = organizerToneColors(p, tone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: orgText(p, size: 14, height: 1.5),
                ),
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
