import 'package:flutter/material.dart';

import '../screens/organizer/app_colors.dart';
import '../theme/fairtix_palette.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// White rounded panel with a light border and soft shadow.
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: palette.isDark
            ? const []
            : [
                BoxShadow(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: palette.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 10),
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
            style: TextStyle(color: palette.danger, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
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
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
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
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontSize: 10),
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
        runSpacing: 12,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}

/// Column header style used by the admin tables.
const adminHeaderStyle = TextStyle(
  color: AppColors.textGray,
  fontSize: 9,
  fontWeight: FontWeight.w700,
);
