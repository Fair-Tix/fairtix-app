import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/event.dart';
import '../models/transaction.dart';
import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart';

/// Peso amount without the cents when they are zero: "₱3,000", but
/// "₱2,500.50" keeps its cents.
String formatPesoShort(double amount) {
  final text = formatPeso(amount);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

/// Rounded status badge with a dot ("Completed", "Pending", ...) used on the
/// Transactions list and the Transaction detail screen. Draws with the
/// [FtAuthTheme] handed down by the surrounding scaffold.
class FtTransactionStatusPill extends StatelessWidget {
  const FtTransactionStatusPill({
    super.key,
    required this.status,
    this.large = false,
  });

  final TransactionStatus status;

  /// True = the bigger pill under the amount on the detail screen.
  final bool large;

  String get _label => switch (status) {
        TransactionStatus.completed => 'Completed',
        TransactionStatus.pending => 'Pending',
        TransactionStatus.refundPending => 'Awaiting provider confirmation',
        TransactionStatus.failed => 'Failed',
        TransactionStatus.refunded => 'Refunded',
      };

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final p = FairTixPalette.of(context);
    final (fg, bg) = switch (status) {
      TransactionStatus.completed => (t.success, t.successSurface),
      TransactionStatus.pending => (t.secondaryText, t.isDark ? t.surfaceBorder : t.progressTrack),
      TransactionStatus.refundPending => (p.warning, p.warningSurface),
      TransactionStatus.failed => (t.danger, t.dangerSurface),
      TransactionStatus.refunded => (p.warning, p.warningSurface),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 9 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 8 : 7,
            height: large ? 8 : 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          SizedBox(width: large ? 8 : 7),
          Text(
            _label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: large ? 14 : 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
