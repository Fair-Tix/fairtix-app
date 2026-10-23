import 'dart:async';

import 'package:app_links/app_links.dart';
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

/// Checkout screen for buying another user's resale listing. Works exactly
/// like [CheckoutScreen] (same PayMongo Sandbox flow, same deep-link return),
/// except the price is the listing's resale price:
///  1. `paymongo-checkout` is asked for a Checkout Session for `listingId`.
///     The server validates the buyer and the listing and works out the price
///     itself (resale_checkout_quote in supabase/resale_payment.sql).
///  2. The buyer pays on PayMongo's Sandbox page and is redirected back via
///     `fairtix://payment/success`.
///  3. `paymongo-verify` asks PayMongo whether the session is PAID and only
///     then moves the ticket to the buyer and reissues its QR code. A failed
///     or canceled payment therefore never transfers a ticket.
///  4. `paymongo-webhook` is an independent second path; both are idempotent
///     on the PayMongo session id, so one payment can never buy a ticket twice.
class ResaleCheckoutScreen extends StatefulWidget {
  const ResaleCheckoutScreen({super.key, required this.listing});

  final Ticket listing;

  @override
  State<ResaleCheckoutScreen> createState() => _ResaleCheckoutScreenState();
}

enum _CheckoutStage { review, creatingLink, awaitingPayment, finalizing }

class _ResaleCheckoutScreenState extends State<ResaleCheckoutScreen> with WidgetsBindingObserver {
  _CheckoutStage _stage = _CheckoutStage.review;
  String? _checkoutUrl;
  String? _sessionId;
  String? _errorMessage;
  bool _verifying = false;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // PayMongo redirects the browser to fairtix://payment/success (or /cancel)
    // after the buyer authorizes; the OS reopens the app with that link.
    _linkSub = AppLinks().uriLinkStream.listen(_handleDeepLink, onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fallback if the browser redirect didn't fire: when the buyer switches
    // back to the app while a payment is pending, quietly check it.
    if (state == AppLifecycleState.resumed && _stage == _CheckoutStage.awaitingPayment) {
      _verifyPayment(attempts: 1, silent: true);
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'fairtix' || uri.host != 'payment') return;
    if (_stage != _CheckoutStage.awaitingPayment) return;
    final result = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (result == 'cancel') {
      setState(() {
        _stage = _CheckoutStage.review;
        _errorMessage = 'Payment was canceled. You have not been charged.';
      });
      return;
    }
    // success: confirm with the server. Retry a few times because PayMongo can
    // take a moment to mark the payment as paid after the redirect.
    _verifyPayment(attempts: 6, silent: false);
  }

  Future<void> _handleStartPayment() async {
    final listing = widget.listing;
    final listingId = listing.listingId;
    if (listingId == null) {
      setState(() => _errorMessage = 'This listing can’t be bought. Go back and reopen the Resale Market.');
      return;
    }

    setState(() {
      _stage = _CheckoutStage.creatingLink;
      _errorMessage = null;
    });

    try {
      // No amount is sent: the server uses the listing's price and refuses the
      // checkout if the listing is gone, it's the buyer's own, the resale
      // window has closed, or the buyer already holds a ticket for that day.
      final response = await Supabase.instance.client.functions.invoke(
        'paymongo-checkout',
        body: {
          'description': 'Resale – ${listing.tier.name} – ${listing.event.title}',
          'listingId': listingId,
        },
      );

      final data = response.data;

      // A free (price 0) listing never goes to PayMongo: the server has
      // already handed over the ticket and says so.
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

      if (data is! Map || data['checkout_url'] == null || data['session_id'] == null) {
        final errorText = (data is Map ? data['error'] as String? : null) ??
            'Could not start the PayMongo checkout.';
        throw Exception(errorText);
      }

      final url = data['checkout_url'] as String;
      setState(() {
        _checkoutUrl = url;
        _sessionId = data['session_id'] as String;
        _stage = _CheckoutStage.awaitingPayment;
      });

      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _errorMessage = 'Could not open the payment page automatically. Use the link below.');
      }
    } on FunctionException catch (e) {
      // The Edge Function refused (e.g. "This listing is no longer
      // available."). Show its plain-sentence message; no payment was started.
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

  /// Confirms the payment with the server and, if PayMongo says it's paid,
  /// receives the ticket (with its new QR) and moves to the confirmation
  /// screen. See [CheckoutScreen._verifyPayment] for the retry rationale.
  Future<void> _verifyPayment({int attempts = 6, bool silent = false}) async {
    if (_verifying) return;
    final sessionId = _sessionId;
    if (sessionId == null) {
      if (!silent) {
        setState(() {
          _stage = _CheckoutStage.review;
          _errorMessage = 'Missing payment reference — please restart checkout.';
        });
      }
      return;
    }

    _verifying = true;
    if (!silent && mounted) {
      setState(() {
        _stage = _CheckoutStage.finalizing;
        _errorMessage = null;
      });
    }

    String? lastMessage;
    try {
      for (var i = 0; i < attempts; i++) {
        try {
          final response = await Supabase.instance.client.functions.invoke(
            'paymongo-verify',
            body: {'sessionId': sessionId},
          );
          final row = response.data;
          if (row is Map && row['ticket_id'] != null && row['qr_code_token'] != null) {
            _verifying = false;
            _finishPurchase(
              ticketId: row['ticket_id'] as String,
              qrToken: row['qr_code_token'] as String,
            );
            return;
          }
          lastMessage = (row is Map ? row['error'] as String? : null) ??
              'Could not confirm your payment.';
        } on FunctionException catch (e) {
          final details = e.details;
          lastMessage = (details is Map ? details['error'] as String? : null) ??
              'Could not confirm your payment.';
          // 402 = PayMongo doesn't show it as paid (yet): worth retrying.
          // Anything else (403 wrong account, 400, 5xx) won't fix itself.
          if (e.status != 402) break;
        }
        if (i < attempts - 1) {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
        }
      }
    } catch (e) {
      lastMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _verifying = false;
    }

    if (!mounted) return;
    setState(() {
      _stage = _CheckoutStage.awaitingPayment;
      _errorMessage = silent ? null : lastMessage;
    });
  }

  /// Runs once the server has handed the ticket to the buyer: refreshes what
  /// the purchase changed (wallet, transactions, notifications, event stock)
  /// and shows the confirmation screen.
  void _finishPurchase({required String ticketId, required String qrToken}) {
    final listing = widget.listing;

    unawaited(TicketRepository.instance.refresh().catchError((_) {}));
    unawaited(TransactionRepository.instance.refresh().catchError((_) {}));
    unawaited(NotificationRepository.instance.refresh().catchError((_) {}));
    unawaited(PublicEventRepository.instance.refresh().catchError((_) {}));

    if (!mounted) return;
    final newTicket = Ticket(
      id: ticketId,
      event: listing.event,
      tier: listing.tier,
      ownerName: UserSession.instance.account?.fullName ?? 'FairTix User',
      qrToken: qrToken,
      purchasePrice: listing.purchasePrice,
    );

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
    final isFree = resalePrice <= 0;
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
                              '${listing.tier.name} – ${listing.event.title}',
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
                        isFree ? 'Free' : formatPeso(resalePrice),
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
                                ? 'This listing is free — no payment is needed. Tap the button below to get it.'
                                : 'You’ll pay via PayMongo’s Sandbox checkout page (test mode — no real money is processed). The ticket is transferred to you once the payment is confirmed.',
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
                      'A PayMongo Sandbox payment page opened in your browser. After you authorize the test payment there, you’ll be brought back here automatically and your ticket will be confirmed.',
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
            if (_stage == _CheckoutStage.awaitingPayment || _stage == _CheckoutStage.finalizing)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accentPurple),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _stage == _CheckoutStage.finalizing ? 'Confirming your payment…' : 'Waiting for your payment…',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accentPurple),
                  ),
                ],
              )
            else
              GradientPillButton(
                label: isFree ? 'Get Free Ticket' : 'Pay with PayMongo',
                loading: isBusy,
                onPressed: _handleStartPayment,
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
