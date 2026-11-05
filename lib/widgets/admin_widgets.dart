import 'package:flutter/material.dart';

import '../screens/organizer/app_colors.dart';
import '../theme/fairtix_palette.dart';
import 'organizer_ui.dart';

/// Small building blocks shared by the admin screens (Events & Tickets,
/// Resale Monitoring, Fraud Alerts, Dashboard, Revenue & Reports), so each
/// screen isn't re-implementing badges, cards and money formatting.

/// "₱12,345.50". Negative amounts keep their sign in front of the peso sign.
String formatPeso(num amount) {
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${amount < 0 ? '-' : ''}\u20B1$whole.${parts[1]}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Oct 13, 2026".
String formatAdminDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Oct 13, 2026 2:34 PM".
String formatAdminDateTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '${formatAdminDate(d)} $hour:$minute $suffix';
}

/// "2026-10-13": used in exported file names and CSV cells.
String formatIsoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A small rounded status pill.
class AdminBadge extends StatelessWidget {
  const AdminBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  factory AdminBadge.success(String label) => AdminBadge(
    label: label,
    color: AppColors.successGreen,
    background: AppColors.successGreenBg,
  );

  factory AdminBadge.danger(String label) => AdminBadge(
    label: label,
    color: AppColors.dangerRed,
    background: AppColors.dangerRedBg,
  );

  factory AdminBadge.warning(String label) => AdminBadge(
    label: label,
    color: AppColors.warningOrange,
    background: AppColors.warningOrangeBg,
  );

  factory AdminBadge.info(String label) => AdminBadge(
    label: label,
    color: AppColors.infoBlue,
    background: AppColors.infoBlueBg,
  );

  factory AdminBadge.neutral(String label) => AdminBadge(
    label: label,
    color: AppColors.textGray,
    background: const Color(0xFFF3F4F6),
  );

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    final badgeColor = !palette.isDark
        ? color
        : color == AppColors.successGreen
        ? palette.success
        : color == AppColors.dangerRed
        ? palette.danger
        : color == AppColors.warningOrange
        ? palette.warning
        : color == AppColors.infoBlue
        ? palette.accentLabel
        : palette.textSecondary;
    final badgeBackground = !palette.isDark
        ? background
        : color == AppColors.successGreen
        ? palette.successSurface
        : color == AppColors.dangerRed
        ? palette.dangerSurface
        : color == AppColors.warningOrange
        ? palette.warningSurface
        : color == AppColors.infoBlue
        ? palette.primary.withValues(alpha: 0.18)
        : palette.progressTrack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: orgText(
          palette,
          size: 11,
          weight: FontWeight.w700,
          color: badgeColor,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Rounded surface panel with a light border and soft shadow, matching the
/// organizer cards.
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
        boxShadow: palette.isDark
            ? const []
            : [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Centered icon + title + hint, for an empty list.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primary.withValues(
                  alpha: palette.isDark ? 0.20 : 0.08,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 28, color: palette.accentLabel),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: orgText(palette, size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: orgText(palette, size: 13, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A load-failed message with a Retry button.
class AdminErrorBox extends StatelessWidget {
  const AdminErrorBox({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: orgText(palette, size: 14, color: palette.danger),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textPrimary,
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              textStyle: orgText(palette, size: 14, weight: FontWeight.w700),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// One headline-number card.
class AdminSummaryCard extends StatelessWidget {
  const AdminSummaryCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = FairTixPalette.of(context);
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      palette,
                      size: 13,
                      weight: FontWeight.w500,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: orgText(
                  palette,
                  size: 28,
                  weight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                overflow: TextOverflow.ellipsis,
                style: orgText(
                  palette,
                  size: 12,
                  color: palette.textSecondary,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lays [cards] out in a responsive row (all in one row when wide, two per
/// row on a tablet, stacked on a phone).
class AdminSummaryRow extends StatelessWidget {
  const AdminSummaryRow({super.key, required this.cards});

  final List<AdminSummaryCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 900
          ? cards.length
          : (constraints.maxWidth > 520 ? 2 : 1);
      final width = ((constraints.maxWidth - 16 * (columns - 1)) / columns)
          .floorToDouble();
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}

/// Page title (plus optional subtitle) with action buttons on the right. On
/// narrow screens the actions drop below the title.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final narrow = MediaQuery.of(context).size.width < 700;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: orgText(
            p,
            size: narrow ? 24 : 30,
            weight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
        ],
      ],
    );
    final buttons = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
      children: actions,
    );
    if (actions.isEmpty) return heading;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: 14), buttons],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 16),
        // Sized to its content (not a flex slot) so the actions sit flush
        // against the right edge instead of floating mid-header.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: buttons,
        ),
      ],
    );
  }
}

/// Rounded action button for page headers. [filled] uses the purple gradient;
/// otherwise it is an outlined surface button. A null [onPressed] dims it.
class AdminHeaderButton extends StatelessWidget {
  const AdminHeaderButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);
    final fg = filled ? Colors.white : p.accentLabel;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: filled ? FairTixPalette.buttonGradient : null,
            color: filled ? null : p.surface,
            border: filled ? null : Border.all(color: p.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: orgText(
                      p,
                      size: 13,
                      weight: FontWeight.w700,
                      color: fg,
                      height: 1.2,
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

/// Square outlined icon-only button for page headers (e.g. refresh). While
/// [loading] it shows a small spinner instead of the icon; a null [onPressed]
/// with [loading] false dims it.
class AdminIconButton extends StatelessWidget {
  const AdminIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(12);
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: p.surface,
              border: Border.all(color: p.border),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.accentLabel,
                          ),
                        )
                      : Icon(icon, size: 18, color: p.accentLabel),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped filter tabs (All / Pending / ...). [counts], when given, must
/// have one entry per label; a null entry shows the label alone.
class AdminFilterChips extends StatelessWidget {
  const AdminFilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<int?>? counts;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final counts = this.counts;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: i == selected ? FairTixPalette.buttonGradient : null,
                  color: i == selected ? null : p.surface,
                  border: i == selected ? null : Border.all(color: p.border),
                ),
                child: Text(
                  counts != null && counts[i] != null
                      ? '${labels[i]} (${counts[i]})'
                      : labels[i],
                  style: orgText(
                    p,
                    size: 13,
                    weight: i == selected ? FontWeight.w700 : FontWeight.w500,
                    color: i == selected ? Colors.white : p.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small pill action used inside table rows ("Review", "View"). [filled]
/// highlights the primary action; a null [onPressed] dims it.
class AdminRowAction extends StatelessWidget {
  const AdminRowAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  /// Accent color for the outlined style (defaults to the purple accent).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final enabled = onPressed != null;
    final accent = color ?? p.accentLabel;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: filled ? FairTixPalette.buttonGradient : null,
              border: filled
                  ? null
                  : Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              label,
              style: orgText(
                p,
                size: 12,
                weight: FontWeight.w700,
                color: filled ? Colors.white : accent,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded search box for list screens.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 280,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final style = orgText(p, size: 13, height: 1.3);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return SizedBox(
      width: width,
      height: 42,
      child: TextField(
        onChanged: onChanged,
        style: style,
        cursorColor: p.accentLabel,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: style.copyWith(color: p.textSecondary),
          prefixIcon: Icon(Icons.search, size: 18, color: p.textSecondary),
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: border(p.border),
          enabledBorder: border(p.border),
          focusedBorder: border(p.accentLabel),
        ),
      ),
    );
  }
}

/// Header row of an admin table. [flex] gives each column's relative width and
/// must match the cells built with [adminCell] / [Expanded] in the rows.
class AdminTableHeader extends StatelessWidget {
  const AdminTableHeader({super.key, required this.labels, required this.flex});

  final List<String> labels;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: p.progressTrack,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(
                labels[i].toUpperCase(),
                style: orgText(
                  p,
                  size: 11,
                  weight: FontWeight.w700,
                  color: p.textSecondary,
                  letterSpacing: 0.6,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One text cell of an admin table row (an [Expanded], so use it directly as a
/// child of the row's [Row]).
Widget adminCell(
  BuildContext context,
  int flex,
  String text, {
  bool bold = false,
  bool muted = false,
}) {
  final p = FairTixPalette.of(context);
  return Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: orgText(
          p,
          size: bold ? 14 : 13,
          weight: bold ? FontWeight.w700 : FontWeight.w400,
          color: muted ? p.textSecondary : p.textPrimary,
          height: 1.3,
        ),
      ),
    ),
  );
}

/// Row container for an admin table: top hairline, standard padding.
class AdminTableRow extends StatelessWidget {
  const AdminTableRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(children: children),
    );
  }
}

/// On/off pill for a single boolean filter (e.g. "Near floor only"). Uses the
/// danger color when on, since it is used for flagged items.
class AdminToggleChip extends StatelessWidget {
  const AdminToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final fg = selected ? p.danger : p.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? p.dangerSurface : p.surface,
            border: Border.all(color: selected ? p.danger : p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: orgText(
                  p,
                  size: 13,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Themed [AlertDialog] shared by the admin screens.
class AdminDialog extends StatelessWidget {
  const AdminDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      title: Text(
        title,
        style: orgText(p, size: 18, weight: FontWeight.w800),
      ),
      content: content,
      actions: actions,
    );
  }
}

/// Body text for an [AdminDialog].
class AdminDialogText extends StatelessWidget {
  const AdminDialogText(this.text, {super.key, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Text(
      text,
      style: orgText(p, size: small ? 12 : 14, color: p.textSecondary),
    );
  }
}

/// Text button for an [AdminDialog]'s actions; [color] defaults to the normal
/// text color (use danger / success for destructive / confirming actions).
class AdminDialogButton extends StatelessWidget {
  const AdminDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: orgText(
          p,
          size: 14,
          weight: FontWeight.w700,
          color: color ?? p.textPrimary,
        ),
      ),
    );
  }
}

/// Rounded, theme-aware input decoration for text fields inside admin dialogs
/// and forms.
InputDecoration adminInputDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? errorText,
}) {
  final p = FairTixPalette.of(context);
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c),
  );
  final style = orgText(p, size: 14, color: p.textSecondary);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    labelStyle: style,
    hintStyle: style,
    errorStyle: orgText(p, size: 12, color: p.danger),
    border: border(p.border),
    enabledBorder: border(p.border),
    focusedBorder: border(p.accentLabel),
    errorBorder: border(p.danger),
    focusedErrorBorder: border(p.danger),
  );
}

/// Column header style used by the admin tables.
const adminHeaderStyle = TextStyle(
  color: AppColors.textGray,
  fontSize: 11,
  fontWeight: FontWeight.w700,
);
