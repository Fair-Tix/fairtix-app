import 'package:flutter/material.dart';

import '../../data/sample_tickets.dart';
import '../../data/sample_transactions.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/purple_header_bar.dart';
import 'checkout_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.event, required this.tier});

  final EventSummary event;
  final TicketTier tier;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;

  Future<void> _handleConfirmPurchase() async {
    setState(() => _isProcessing = true);
    // TODO: replace with a real PayMongo Sandbox checkout session + escrow
    // hold via Cloud Functions once the payment backend is wired up.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final newTicket = Ticket(
      id: 'tkt_${DateTime.now().millisecondsSinceEpoch}',
      event: widget.event,
      tier: widget.tier,
      ownerName: 'Heron Dave Mahilum',
      qrToken: 'FTX-${DateTime.now().millisecondsSinceEpoch}',
    );
    sampleMyTickets.add(newTicket);

    final ticketPrice = widget.tier.price;
    final platformFee = ticketPrice * kPrimaryPlatformFeeRate;
    final total = ticketPrice + platformFee;

    sampleTransactions.add(
      AppTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        eventTitle: widget.event.title,
        tierName: widget.tier.name,
        category: TransactionCategory.ticketPurchase,
        subtotal: ticketPrice,
        platformFee: platformFee,
        amount: total,
        dateTime: DateTime.now(),
        paymentMethod: 'PayMongo Sandbox (Simulated)',
        ticketId: newTicket.id,
      ),
    );

    setState(() => _isProcessing = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CheckoutConfirmationScreen(
          event: widget.event,
          tier: widget.tier,
          purchasedTicket: newTicket,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketPrice = widget.tier.price;
    final platformFee = ticketPrice * kPrimaryPlatformFeeRate;
    final total = ticketPrice + platformFee;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Checkout',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                  Text('Order Summary', style: AppTextStyles.sectionHeading),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.inputBorderLight, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.event.accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.music_note_rounded, color: AppColors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.tier.name} \u2013 ${widget.event.title}',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentPurple,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.tier.name.toUpperCase(),
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.inputBorderLight, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ticket Price', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      Text(
                        formatPeso(total),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.accentPurple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                            'This is a simulated payment — no real money is processed.',
                            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientPillButton(
              label: 'Confirm Purchase',
              loading: _isProcessing,
              onPressed: _handleConfirmPurchase,
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Cancel and go back',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
