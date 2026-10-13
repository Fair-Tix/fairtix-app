import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../services/transaction_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/purple_header_bar.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

/// "Transactions" screen — every payment the current user has made or
/// received (ticket purchases, resale purchases, resale sales), newest
/// first, backed by [TransactionRepository] (real query against
/// `public.transactions`). Reached from the Profile tab, or directly from
/// a "your ticket has been bought" notification.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await TransactionRepository.instance.refresh();
    } on TransactionRepositoryException catch (e) {
      _errorMessage = e.message;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openTransaction(BuildContext context, AppTransaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: transaction)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = TransactionRepository.instance.transactions;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Transactions',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentPurple))
            : _errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Text(_errorMessage!, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            TextButton(onPressed: _loadTransactions, child: const Text('Try again')),
                          ],
                        ),
                      ),
                    ],
                  )
                : transactions.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
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
                          ),
                        ],
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
      ),
    );
  }
}
