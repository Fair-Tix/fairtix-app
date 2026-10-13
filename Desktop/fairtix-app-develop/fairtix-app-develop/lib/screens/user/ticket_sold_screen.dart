import 'package:flutter/material.dart';

import '../../data/sample_transactions.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../models/transaction.dart';
import '../../navigation/app_nav.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/pill_button.dart';
import 'transaction_detail_screen.dart';
import 'transactions_screen.dart';

/// Seller-side confirmation shown when tapping a "your ticket has been
/// bought" notification — confirms the resale completed, the QR code
/// was transferred to the buyer, and the sale amount was credited.
class TicketSoldScreen extends StatelessWidget {
  const TicketSoldScreen({
    super.key,
    required this.ticket,
    required this.buyerName,
    required this.salePrice,
  });

  final Ticket ticket;
  final String buyerName;
  final double salePrice;

  void _handleViewTransaction(BuildContext context) {
    AppTransaction? match;
    for (final t in sampleTransactions) {
      if (t.ticketId == ticket.id) {
        match = t;
        break;
      }
    }
    if (match != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: match!)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ticket.event;
    return Scaffold(
      body: GradientBackground(
        gradient: AppGradients.confirmation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: AppColors.white.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.accentPurple, size: 40),
              ),
              const SizedBox(height: 26),
              Text('Ticket Sold!', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'Your resale is complete and your QR code has been transferred to the buyer',
                textAlign: TextAlign.center,
                style: AppTextStyles.tagline,
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.white),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.fieldBorder, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sale Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.subtleWhite)),
                        Text(
                          formatPeso(salePrice),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Buyer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.subtleWhite)),
                        Row(
                          children: const [
                            Text('Confirmed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.white)),
                            SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Funds have been added to your account',
                      style: AppTextStyles.tagline.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              PillButton(
                label: 'View Transaction',
                onPressed: () => _handleViewTransaction(context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => navigateToTab(context, 1),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.white, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    'Back to My Tickets',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
