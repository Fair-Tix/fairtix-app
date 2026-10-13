import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/notification_repository.dart';
import '../../services/public_event_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/transaction_repository.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/purple_header_bar.dart';
import 'checkout_confirmation_screen.dart';

/// Real checkout flow:
///  1. Ask the `paymongo-checkout` Supabase Edge Function to create a
///     PayMongo Sandbox Payment Link (the function holds the PayMongo
///     secret key — see supabase/functions/paymongo-checkout/index.ts).
///  2. Open that link in the browser so the buyer pays on PayMongo's own
///     Sandbox checkout page.
///  3. Once the buyer taps "I've completed payment", call the
///     `paymongo-verify` Edge Function (supabase/functions/paymongo-verify),
///     which asks PayMongo directly whether the link is PAID and only then
///     issues the ticket (atomically checking stock, creating the
///     `tickets` row, recording the `transactions` row, and decrementing
///     `ticket_tiers.remaining_quantity` — see
///     supabase/purchase_functions.sql). A failed or canceled payment
///     therefore never produces a ticket.
///
/// `paymongo-webhook` is a second, independent path that issues the same
/// ticket when PayMongo notifies us server-to-server; both use the same
/// deterministic token, so a payment can never yield two tickets.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.event, required this.tier});

  final EventSummary event;
  final TicketTier tier;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _CheckoutStage { review, creatingLink, awaitingPayment, finalizing }

class _CheckoutScreenState extends State<CheckoutScreen> {
  _CheckoutStage _stage = _CheckoutStage.review;
  String? _checkoutUrl;
  String? _linkId;
  String? _errorMessage;

  Future<void> _handleStartPayment() async {
    setState(() {
      _stage = _CheckoutStage.creatingLink;
      _errorMessage = null;
    });

    try {
      // No amount is sent: the server works out the price itself and also
      // refuses the checkout if this buyer already holds a ticket for this
      // event day, the event isn't on sale, or the tier is sold out.
      final response = await Supabase.instance.client.functions.invoke(
        'paymongo-checkout',
        body: {
          'description': '${widget.tier.name} \u2013 ${widget.event.title}',
          'tierId': widget.tier.id,
        },
      );

      final data = response.data;

      // A free (price 0) tier never goes to PayMongo: the server has already
      // issued the ticket and says so. Go straight to the confirmation.
      if (data is Map &&
          data['free'] == true &&
          data['ticket_id'] != null &&
          data['qr_code_token'] != null) {
        _finishPurchase(
          ticketId: data['ticket_id'] as String,
          qrToken: data['qr_code_token'] as String,
        );
        return;
      }

      if (data is! Map || data['checkout_url'] == null || data['link_id'] == null) {
        final errorText = (data is Map ? data['error'] as String? : null) ??
            'Could not start the PayMongo checkout.';
        throw Exception(errorText);
      }

      final url = data['checkout_url'] as String;
      setState(() {
        _checkoutUrl = url;
        _linkId = data['link_id'] as String;
        _stage = _CheckoutStage.awaitingPayment;
      });

      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _errorMessage = 'Could not open the payment page automatically. Use the link below.');
      }
    } on FunctionException catch (e) {
      // The Edge Function refused (e.g. "You can only hold one ticket per
      // event day"). Show its plain-sentence message; no payment was started.
      if (!mounted) return;
      final details = e.details;
      final message = (details is Map ? details['error'] as String? : null) ??
          'Could not start the PayMongo checkout. Please try again.';
      setState(() {
        _stage = _CheckoutStage.review;
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _CheckoutStage.review;
        _errorMessage = 'Could not start payment: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _handleConfirmPaid() async {
    setState(() {
      _stage = _CheckoutStage.finalizing;
      _errorMessage = null;
    });

    // Deterministic token derived from the PayMongo link id — matches what
    // paymongo-webhook computes server-side when PayMongo itself confirms
    // the payment. Whichever of the two fires first actually creates the
    // ticket; the other safely becomes a no-op (see _do_ticket_purchase in
    // supabase/purchase_functions.sql), so a ticket is never double-issued
    // for one payment no matter which path lands first.
    final linkId = _linkId;
    if (linkId == null) {
      setState(() {
        _stage = _CheckoutStage.awaitingPayment;
        _errorMessage = 'Missing payment reference — please restart checkout.';
      });
      return;
    }

    try {
      // paymongo-verify asks PayMongo itself whether this link is paid and
      // only then issues the ticket. If the payment failed, was canceled,
      // or never happened, it returns an error and NO ticket is created.
      final response = await Supabase.instance.client.functions.invoke(
        'paymongo-verify',
        body: {'linkId': linkId},
      );

      final row = response.data;
      if (row is! Map || row['ticket_id'] == null || row['qr_code_token'] == null) {
        final errorText = (row is Map ? row['error'] as String? : null) ??
            'Could not confirm your payment. Please try again.';
        throw Exception(errorText);
      }

      _finishPurchase(
        ticketId: row['ticket_id'] as String,
        qrToken: row['qr_code_token'] as String,
      );
    } on FunctionException catch (e) {
      // The Edge Function answered with a non-2xx (e.g. 402 payment not
      // completed). Show its message and stay on the payment step so the
      // buyer can finish paying or reopen the link — no ticket exists.
      if (!mounted) return;
      final details = e.details;
      final message = (details is Map ? details['error'] as String? : null) ??
          'Could not confirm your payment. Please try again.';
      setState(() {
        _stage = _CheckoutStage.awaitingPayment;
        _errorMessage = message;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _CheckoutStage.awaitingPayment;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _CheckoutStage.awaitingPayment;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Runs once the server has issued the ticket — after a verified PayMongo
  /// payment, or immediately for a free (price 0) tier: builds the local
  /// [Ticket], refreshes the caches, and shows the confirmation screen.
  void _finishPurchase({required String ticketId, required String qrToken}) {
    final newTicket = Ticket(
      id: ticketId,
      event: widget.event,
      tier: widget.tier,
      ownerName: UserSession.instance.account?.fullName ?? 'FairTix User',
      qrToken: qrToken,
    );

    // Refresh the real My Tickets / Transactions caches (see
    // TicketRepository / TransactionRepository) so they reflect this
    // purchase the moment those screens are next opened, instead of
    // showing stale data until their own next manual refresh.
    unawaited(TicketRepository.instance.refresh());
    unawaited(TransactionRepository.instance.refresh());
    // Also reload the event catalogue so ticket_tiers.remaining_quantity
    // (just decremented server-side) shows its new value everywhere.
    unawaited(PublicEventRepository.instance.refresh());
    // The purchase trigger (supabase/purchase_notification.sql) has already
    // written the "Ticket Purchased" notification; pull it in so the
    // dashboard's unread dot shows it without opening Notifications first.
    // Errors are swallowed: the Notifications screen reloads on its own.
    unawaited(NotificationRepository.instance.refresh().catchError((_) {}));

    if (!mounted) return;
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
    final isFree = ticketPrice <= 0;
    final platformFee = ticketPrice * kPrimaryPlatformFeeRate;
    final total = ticketPrice + platformFee;
    final isBusy = _stage == _CheckoutStage.creatingLink || _stage == _CheckoutStage.finalizing;

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
                        isFree ? 'Free' : formatPeso(total),
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
                            isFree
                                ? 'This ticket is free \u2014 no payment is needed. Tap the button below to get it.'
                                : 'You\u2019ll pay via PayMongo\u2019s Sandbox checkout page (test mode \u2014 no real money is processed).',
                            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_stage == _CheckoutStage.awaitingPayment) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.accentPurple),
                        SizedBox(width: 8),
                        Text('Complete your payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accentPurple)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A PayMongo Sandbox payment page opened in your browser. Once you\u2019ve completed the test payment there, come back and tap the button below.',
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 12.5, height: 1.4),
                    ),
                    if (_checkoutUrl != null) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => launchUrl(Uri.parse(_checkoutUrl!), mode: LaunchMode.externalApplication),
                        child: Text(
                          'Reopen payment page',
                          style: AppTextStyles.bodyMuted.copyWith(
                            fontSize: 12.5,
                            color: AppColors.accentPurple,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
              label: _stage == _CheckoutStage.awaitingPayment
                  ? 'I\u2019ve Completed Payment'
                  : (isFree ? 'Get Free Ticket' : 'Pay with PayMongo'),
              loading: isBusy,
              onPressed: _stage == _CheckoutStage.awaitingPayment ? _handleConfirmPaid : _handleStartPayment,
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
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
