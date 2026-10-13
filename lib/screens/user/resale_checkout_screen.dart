import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/notification_repository.dart';
import '../../services/resale_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/transaction_repository.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/purple_header_bar.dart';
import 'checkout_confirmation_screen.dart';

/// Checkout screen for buying another user's resale listing.
/// Mirrors [CheckoutScreen] but sources its price from the listing's
/// resale price instead of the tier's original price. Confirming calls the
/// `buy_resale_listing` database function (supabase/resale_purchase.sql),
/// which transfers the ticket, issues the buyer a new QR code, records the
/// transaction and notifies both sides, all in one step.
///
/// Payment is simulated (no real money moves), as the notice on screen says.
class ResaleCheckoutScreen extends StatefulWidget {
  const ResaleCheckoutScreen({super.key, required this.listing});

  final Ticket listing;

  @override
  State<ResaleCheckoutScreen> createState() => _ResaleCheckoutScreenState();
}

class _ResaleCheckoutScreenState extends State<ResaleCheckoutScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _handleConfirmPurchase() async {
    final listing = widget.listing;
    final listingId = listing.listingId;
    if (_isProcessing) return;
    if (listingId == null) {
      setState(() => _errorMessage = 'This listing can\u2019t be bought. Go back and reopen the Resale Market.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final BoughtTicket bought;
    try {
      bought = await ResaleRepository.instance.buyListing(listingId);
    } on ResaleException catch (e) {
      // Nothing was bought (listing gone, purchase limit, window closed...).
      // Stay here and say why.
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });
      return;
    }

    // The purchase is done. Refresh what it changed: the wallet (new ticket,
    // which also feeds the one-ticket-per-event check), the transaction
    // history, and the notifications the database just wrote.
    unawaited(TicketRepository.instance.refresh().catchError((_) {}));
    unawaited(TransactionRepository.instance.refresh().catchError((_) {}));
    unawaited(NotificationRepository.instance.refresh().catchError((_) {}));

    if (!mounted) return;
    final newTicket = Ticket(
      id: bought.ticketId,
      event: listing.event,
      tier: listing.tier,
      ownerName: UserSession.instance.account?.fullName ?? 'FairTix User',
      qrToken: bought.qrToken,
      purchasePrice: listing.purchasePrice,
    );

    setState(() => _isProcessing = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CheckoutConfirmationScreen(
          event: listing.event,
          tier: listing.tier,
          purchasedTicket: newTicket,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    // The buyer pays exactly the listing price; FairTix's resale fee comes out
    // of the seller's proceeds.
    final resalePrice = listing.resalePrice ?? listing.tier.price;

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
                          color: listing.event.accentColor,
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
                              '${listing.tier.name} \u2013 ${listing.event.title}',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPurple,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    listing.tier.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.white),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Sold by ${listing.ownerName}', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.inputBorderLight, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Resale Price', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      Text(
                        formatPeso(resalePrice),
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 12.5, color: AppColors.error, height: 1.4),
                ),
              ),
            ],
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
