import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

/// Row for a single transaction in the Transactions list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, required this.onTap});

  final AppTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isCredit ? AppColors.success : AppColors.textDark;
    final amountPrefix = transaction.isCredit ? '+' : '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(transaction.categoryIcon, color: AppColors.accentPurple, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transaction.tierName} \u2013 ${transaction.eventTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.categoryLabel} \u2022 ${formatDateTime(transaction.dateTime).split(' \u2022 ').first}',
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$amountPrefix${formatPeso(transaction.amount).replaceAll('.00', '')}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
