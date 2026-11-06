import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/transaction.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_subpage_ui.dart';
import '../../widgets/ft_transaction_ui.dart';

/// Detail view for a single transaction: the amount and status on top, then
/// event, date, payment method, fees and the reference number (tap the copy
/// icon to copy it). Shows only the final total the buyer paid or received;
/// the platform-fee split is internal (organizer/admin) accounting, except
/// for the flat resale fee a seller sees on their own sale.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final AppTransaction transaction;

  /// The fee line for this kind of transaction, or null when none applies
  /// (refunds). Buyers never pay a fee; a seller sees what FairTix kept.
  ({String label, String value})? get _feeRow {
    switch (transaction.category) {
      case TransactionCategory.refund:
        return null;
      case TransactionCategory.resaleSale:
        final fee = transaction.platformFee;
        if (fee == null) return null;
        return (label: 'Resale fee', value: '−${formatPesoShort(fee)}');
      case TransactionCategory.ticketPurchase:
      case TransactionCategory.resalePurchase:
        return (label: 'Buyer fees', value: 'None');
    }
  }

  Future<void> _copyReference(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: transaction.referenceNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Reference copied'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final fee = _feeRow;
    return FtSubpageScaffold(
      title: 'Transaction',
      onBack: () => Navigator.of(context).maybePop(),
      followTheme: true,
      body: [
        _SummaryCard(transaction: transaction),
        const SizedBox(height: 18),
        _DetailsCard(
          rows: [
            _DetailRow(
              label: 'Event',
              value: '${transaction.eventTitle} · ${transaction.tierName}',
            ),
            _DetailRow(label: 'Date', value: formatMediumDate(transaction.dateTime)),
            _DetailRow(label: 'Paid with', value: transaction.paymentMethod),
            if (fee != null) _DetailRow(label: fee.label, value: fee.value),
            _DetailRow(
              label: 'Reference',
              value: transaction.referenceNumber,
              onCopy: () => _copyReference(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Top card: what kind of transaction it was, the amount, and the status.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.transaction});

  final AppTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Column(
        children: [
          Text(
            transaction.categoryLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: t.subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatPesoShort(transaction.amount),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 44,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: t.titleColor,
            ),
          ),
          const SizedBox(height: 16),
          FtTransactionStatusPill(status: transaction.status, large: true),
        ],
      ),
    );
  }
}

/// Bottom card: label / value rows.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;

  /// When set, a copy icon follows the value.
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: t.subtitleColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: t.titleColor,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.copy_rounded,
                size: 19,
                semanticLabel: 'Copy reference',
                color: t.activeAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
