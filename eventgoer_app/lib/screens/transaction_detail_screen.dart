import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/dashed_divider.dart';
import '../widgets/purple_header_bar.dart';

/// Receipt-style detail view for a single transaction — amount, date &
/// time, category, and payment method. Shows only the final total the
/// buyer paid or received; the platform-fee split is internal
/// (organizer/admin) accounting and isn't shown here.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final AppTransaction transaction;

  Color get _statusColor => switch (transaction.status) {
        TransactionStatus.completed => AppColors.success,
        TransactionStatus.pending => AppColors.warning,
        TransactionStatus.failed => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isCredit ? AppColors.success : AppColors.textDark;
    final amountPrefix = transaction.isCredit ? '+' : '-';

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Receipt',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(transaction.categoryIcon, color: AppColors.accentPurple, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              '$amountPrefix${formatPeso(transaction.amount)}',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: amountColor),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 13, color: _statusColor),
                  const SizedBox(width: 5),
                  Text(transaction.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transaction.tierName} \u2013 ${transaction.eventTitle}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 18),
                  _receiptRow('Reference No.', transaction.referenceNumber),
                  const SizedBox(height: 12),
                  _receiptRow('Date & Time', formatDateTime(transaction.dateTime)),
                  const SizedBox(height: 12),
                  _receiptRow('Category', transaction.categoryLabel),
                  const SizedBox(height: 12),
                  _receiptRow('Payment Method', transaction.paymentMethod),
                  const SizedBox(height: 18),
                  const DashedDivider(),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      Text(
                        '$amountPrefix${formatPeso(transaction.amount)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.accentPurple),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFillLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.accentPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a simulated transaction record — no real money was processed.',
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
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

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMuted),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
