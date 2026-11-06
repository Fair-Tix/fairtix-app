import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ticket.dart';
import '../../services/notification_repository.dart';
import '../../services/public_event_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/transaction_repository.dart';
import '../../services/user_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/ft_subpage_ui.dart';
import '../../widgets/ft_transaction_ui.dart' show formatPesoShort;
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

  /// Payment method the buyer picked (a PayMongo method type). The server
  /// limits the PayMongo page to it; an older server ignores it and shows all.
  String _method = 'gcash';
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
          'paymentMethod': _method,
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

  static const _methods = [
    (label: 'GCash', type: 'gcash'),
    (label: 'Maya', type: 'paymaya'),
    (label: 'Card', type: 'card'),
  ];

  /// "Hanz" -> "H•••z": the seller is only identified by their first name,
  /// and only by its ends.
  String _maskName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Verified seller';
    if (clean.length <= 2) return '${clean[0]}•••';
    return '${clean[0]}•••${clean[clean.length - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final listing = widget.listing;
    // The buyer pays exactly the listing price; FairTix's resale fee comes out
    // of the seller's proceeds.
    final resalePrice = listing.resalePrice ?? listing.tier.price;
    final isFree = resalePrice <= 0;
    final isBusy = _stage == _CheckoutStage.creatingLink || _stage == _CheckoutStage.finalizing;
    final waiting = _stage == _CheckoutStage.awaitingPayment || _stage == _CheckoutStage.finalizing;

    return FtSubpageScaffold(
      title: 'Resale checkout',
      onBack: isBusy ? null : () => Navigator.of(context).maybePop(),
      followTheme: true,
      bottomButton: waiting
          ? SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: t.activeAccent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _stage == _CheckoutStage.finalizing
                        ? 'Confirming your payment…'
                        : 'Waiting for your payment…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.activeAccent,
                    ),
                  ),
                ],
              ),
            )
          : FtGradientButton(
              label: isFree ? 'Get free ticket' : 'Buy for ${formatPesoShort(resalePrice)}',
              loading: isBusy,
              onPressed: _handleStartPayment,
            ),
      bottomFooter: TextButton(
        onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
        child: Text(
          'Cancel and go back',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: t.secondaryText,
          ),
        ),
      ),
      body: [
        FtSurfaceCard(
          padding: const EdgeInsets.all(20),
          radius: 26,
          child: Row(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F31B8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 38),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: t.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.tier.name} • ${listing.event.dateLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, color: t.subtitleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seller ${_maskName(listing.ownerName)} · Verified',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, color: t.subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const FtSectionLabel('Pay with'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final method in _methods)
              _MethodPill(
                label: method.label,
                selected: _method == method.type,
                onTap: _stage == _CheckoutStage.review
                    ? () => setState(() => _method = method.type)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 18),
        FtSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          radius: 26,
          child: Column(
            children: [
              FtSummaryRow(
                label: 'Ticket price',
                value: isFree ? 'Free' : formatPesoShort(resalePrice),
              ),
              const SizedBox(height: 14),
              FtSummaryRow(label: 'Face value', value: formatPesoShort(listing.originalPrice)),
              const SizedBox(height: 14),
              FtSummaryRow(label: 'Buyer fees', value: 'None', valueColor: t.success),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: t.divider),
              const SizedBox(height: 16),
              FtSummaryRow(
                label: 'Total',
                value: isFree ? 'Free' : formatPesoShort(resalePrice),
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FtNote(
          icon: Icons.verified_user_outlined,
          text: isFree
              ? 'This listing is free — no payment is needed. Tap the button below to get it.'
              : 'Your payment is held until your new QR is issued.',
        ),
        if (!isFree) ...[
          const SizedBox(height: 10),
          const FtNote(
            icon: Icons.info_outline_rounded,
            text: 'Paid via PayMongo Sandbox (test mode): no real money is processed.',
          ),
        ],
        if (_stage == _CheckoutStage.awaitingPayment) ...[
          const SizedBox(height: 22),
          FtSurfaceCard(
            padding: const EdgeInsets.all(20),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 20, color: t.activeAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Complete your payment',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.activeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'A PayMongo Sandbox payment page opened in your browser. After you authorize the test payment there, you’ll be brought back here automatically and your ticket will be confirmed.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    height: 1.45,
                    color: t.subtitleColor,
                  ),
                ),
                if (_checkoutUrl != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(_checkoutUrl!), mode: LaunchMode.externalApplication),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Reopen payment page',
                        style: t.link().copyWith(decoration: TextDecoration.underline),
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
          FtBanner(message: _errorMessage!),
        ],
      ],
    );
  }
}

/// One of the payment methods (GCash / Maya / Card). The selected one is
/// filled with the brand gradient. [onTap] is null once payment has started.
class _MethodPill extends StatelessWidget {
  const _MethodPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Pay with $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected ? FairTixPalette.buttonGradient : null,
          color: selected ? null : t.surfaceFill,
          border: selected ? null : Border.all(color: t.surfaceBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected ? Colors.white : t.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
