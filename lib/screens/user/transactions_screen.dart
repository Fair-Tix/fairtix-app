import 'package:flutter/material.dart';

import '../../data/sample_transactions.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/purple_header_bar.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

/// "Transactions" screen — every payment the current user has made or
/// received (ticket purchases, resale purchases, resale sales), newest
/// first. Reached from the Profile tab, or directly from a
/// "your ticket has been bought" notification.
/// TODO: replace `sampleTransactions` with a real query against the
/// TRANSACTIONS Firestore collection once the backend is wired up.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  void _openTransaction(BuildContext context, AppTransaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: transaction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = List<AppTransaction>.from(sampleTransactions)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Transactions',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.accentPurple.withValues(alpha: 0.35)),
                  const SizedBox(height: 14),
                  const Text('No transactions yet', style: AppTextStyles.sectionHeading),
                  const SizedBox(height: 6),
                  const Text('Purchases and resale sales will show up here.', style: AppTextStyles.bodyMuted),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return TransactionTile(
                  transaction: transaction,
                  onTap: () => _openTransaction(context, transaction),
                );
              },
            ),
    );
  }
}
