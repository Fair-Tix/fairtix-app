import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../services/notification_repository.dart';
import '../../services/public_event_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/transaction_repository.dart';
import '../../services/user_session.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtBackButton, FtPressScale;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import 'checkout_confirmation_screen.dart';

/// Real checkout flow (fully automatic, no "I've paid" button):
///  1. Ask the `paymongo-checkout` Supabase Edge Function to create a
///     PayMongo Sandbox Checkout Session (the function holds the PayMongo
///     secret key — see supabase/functions/paymongo-checkout/index.ts).
///  2. Open that session in the browser so the buyer pays on PayMongo's own
///     Sandbox checkout page.
///  3. PayMongo redirects the browser to `fairtix://payment/success`, which
///     reopens this app. We catch that deep link and immediately call the
///     `paymongo-verify` Edge Function, which asks PayMongo directly whether
///     the session is PAID and only then issues the ticket. A failed or
///     canceled payment therefore never produces a ticket.
///  4. If the redirect is blocked, we also verify whenever the app returns
///     to the foreground while a payment is pending.
///
/// `paymongo-webhook` is a second, independent path that issues the same
/// ticket when PayMongo notifies us server-to-server; both use the same
/// deterministic token, so a payment can never yield two tickets.
///
/// Follows the Light / Dark switch. The screen lets the buyer switch between the event's tiers
/// before paying; whichever tier is selected is the one sent to the server
/// (which re-checks price, availability and the one-ticket limit itself).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.event, required this.tier});

  final EventSummary event;
  final TicketTier tier;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _CheckoutStage { review, creatingLink, awaitingPayment, finalizing }

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _entranceMs = 750;

  _CheckoutStage _stage = _CheckoutStage.review;
  String? _checkoutUrl;
  String? _sessionId;
  String? _errorMessage;
  bool _verifying = false;
  StreamSubscription<Uri>? _linkSub;

  /// The tier being bought. Starts as the one chosen on Event Details and
  /// can be changed here until a payment is started.
  late TicketTier _tier = widget.tier;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _entranceMs),
  );
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // PayMongo redirects the browser to fairtix://payment/success (or /cancel)
    // after the buyer authorizes; the OS reopens the app with that link.
    _linkSub = AppLinks().uriLinkStream.listen(_handleDeepLink, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _entrance.dispose();
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
          'description': '${_tier.name} \u2013 ${widget.event.title}',
          'tierId': _tier.id,
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

  /// Confirms the payment with the server and, if PayMongo says it's paid,
  /// issues the ticket and moves to the confirmation screen.
  ///
  /// [attempts]: how many times to ask while PayMongo still reports "unpaid"
  /// (HTTP 402) — right after the redirect the payment can lag by a second or
  /// two. [silent]: when true (app-resume fallback) a not-yet-paid result is
  /// ignored instead of shown as an error.
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
          // paymongo-verify asks PayMongo itself whether this session is paid
          // and only then issues the ticket (idempotent via the FTX-<session>
          // token, shared with paymongo-webhook).
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
              paymentMethod: row['payment_method']?.toString(),
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

  /// Runs once the server has issued the ticket — after a verified PayMongo
  /// payment, or immediately for a free (price 0) tier: builds the local
  /// [Ticket], refreshes the caches, and shows the confirmation screen.
  void _finishPurchase({required String ticketId, required String qrToken, String? paymentMethod}) {
    final newTicket = Ticket(
      id: ticketId,
      event: widget.event,
      tier: _tier,
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
          tier: _tier,
          purchasedTicket: newTicket,
          paymentMethod: paymentMethod,
        ),
      ),
    );
  }

  static String _peso(double price) =>
      price <= 0 ? 'Free' : formatPeso(price).replaceAll('.00', '');

  @override
  Widget build(BuildContext context) {
    final ticketPrice = _tier.price;
    final isFree = ticketPrice <= 0;
    final isBusy = _stage == _CheckoutStage.creatingLink || _stage == _CheckoutStage.finalizing;
    final canChangeTier = _stage == _CheckoutStage.review;
    final event = widget.event;
    final tiers = event.tiers.isEmpty ? [widget.tier] : event.tiers;

    final t = FtAuthTheme.live(context);
    TextStyle label() => GoogleFonts.plusJakartaSans(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: t.activeAccent,
        );
    TextStyle meta() => GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: t.secondaryText,
        );

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.overlayStyle,
      child: Scaffold(
        backgroundColor: t.bgBottom,
        body: FtAuthBackground(
          theme: t,
          child: SafeArea(
            child: Column(
              children: [
                FtReveal(
                  animation: _entrance,
                  startMs: 0,
                  endMs: 300,
                  totalMs: _entranceMs,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: Row(
                      children: [
                        FtBackButton(
                          // Same as the old "Cancel and go back": not while
                          // a payment is being set up or confirmed.
                          onTap: () {
                            if (!isBusy) Navigator.of(context).maybePop();
                          },
                        ),
                        const Spacer(),
                        Semantics(
                          header: true,
                          child: Text(
                            'Buy ticket',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FtReveal(
                          animation: _entrance,
                          startMs: 80,
                          endMs: 420,
                          totalMs: _entranceMs,
                          slide: 12,
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [FtColors.progressStart, FtColors.otpButtonEnd],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_outlined,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: FtText.title().copyWith(
                                        fontSize: 27,
                                        letterSpacing: -0.4,
                                        color: t.titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.calendar_today_outlined,
                                                size: 15, color: t.secondaryText),
                                            const SizedBox(width: 6),
                                            Flexible(child: Text(event.dateLabel, style: meta())),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.location_on_outlined,
                                                size: 15, color: t.secondaryText),
                                            const SizedBox(width: 4),
                                            Flexible(child: Text(event.venue, style: meta())),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Semantics(header: true, child: Text('CHOOSE YOUR TICKET', style: label())),
                        const SizedBox(height: 12),
                        for (var i = 0; i < tiers.length; i++) ...[
                          FtReveal(
                            animation: _entrance,
                            startMs: 160 + (i < 4 ? i : 3) * 50,
                            endMs: 160 + (i < 4 ? i : 3) * 50 + 300,
                            totalMs: _entranceMs,
                            slide: 12,
                            child: _TierOption(
                              tier: tiers[i],
                              selected: tiers[i].id == _tier.id,
                              onTap: canChangeTier && !tiers[i].isSoldOut
                                  ? () => setState(() {
                                        _tier = tiers[i];
                                        _errorMessage = null;
                                      })
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!isFree) ...[
                          const SizedBox(height: 10),
                          Semantics(header: true, child: Text('PAY WITH', style: label())),
                          const SizedBox(height: 12),
                          // Information only: PayMongo's own page is where the
                          // buyer picks GCash, Maya or card.
                          ExcludeSemantics(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _MethodChip('GCash'),
                                _MethodChip('Maya'),
                                _MethodChip('Card'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'You\u2019ll pick GCash, Maya or card on PayMongo\u2019s page. '
                            'Test mode \u2014 no real money is processed.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              height: 1.4,
                              color: t.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                          decoration: BoxDecoration(
                            color: t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: t.surfaceBorder),
                          ),
                          child: Column(
                            children: [
                              _SummaryRow(
                                label: _tier.name,
                                value: _peso(ticketPrice),
                              ),
                              const SizedBox(height: 14),
                              // The buyer pays exactly the listed price; FairTix's
                              // fee comes out of the organizer's proceeds.
                              _SummaryRow(
                                label: 'Buyer fees',
                                value: 'None',
                                valueColor: t.success,
                              ),
                              const SizedBox(height: 14),
                              Divider(height: 1, thickness: 1, color: t.surfaceBorder),
                              const SizedBox(height: 14),
                              _SummaryRow(
                                label: 'Total',
                                value: _peso(ticketPrice),
                                strong: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: t.secondaryText,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isFree
                                    ? 'This ticket is free \u2014 no payment is needed. Tap the button below to get it.'
                                    : 'Your payment is held in escrow until your ticket is scanned at the event, '
                                        'or until the day after the event ends.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: t.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_stage == _CheckoutStage.awaitingPayment) ...[
                          const SizedBox(height: 20),
                          _AwaitingPaymentPanel(
                            onReopen: _checkoutUrl == null
                                ? null
                                : () => launchUrl(
                                      Uri.parse(_checkoutUrl!),
                                      mode: LaunchMode.externalApplication,
                                    ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          FtBanner(message: _errorMessage!),
                        ],
                      ],
                    ),
                  ),
                ),
                FtReveal(
                  animation: _entrance,
                  startMs: 300,
                  endMs: 650,
                  totalMs: _entranceMs,
                  slide: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.bgBottom,
                      border: Border(top: BorderSide(color: t.surfaceBorder)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                      child: (_stage == _CheckoutStage.awaitingPayment ||
                              _stage == _CheckoutStage.finalizing)
                          ? SizedBox(
                              height: 58,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: t.activeAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _stage == _CheckoutStage.finalizing
                                        ? 'Confirming your payment\u2026'
                                        : 'Waiting for your payment\u2026',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: t.activeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : FtGradientButton(
                              label: isFree
                                  ? 'Get Free Ticket'
                                  : 'Buy Ticket \u00B7 ${_peso(ticketPrice)}',
                              loading: isBusy,
                              onPressed: _handleStartPayment,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// One selectable tier with a radio-style check on the right.
class _TierOption extends StatelessWidget {
  const _TierOption({required this.tier, required this.selected, required this.onTap});

  final TicketTier tier;
  final bool selected;

  /// Null when the tier can't be chosen (sold out, or a payment is under way).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 180);
    final remaining = tier.remainingQuantity;
    final subtitle = tier.isSoldOut
        ? 'Sold out'
        : (remaining != null && remaining <= 10)
            ? 'Only $remaining left'
            : '1 ticket per account';
    final subtitleColor = tier.isSoldOut ? t.danger : t.secondaryText;
    final price = _CheckoutScreenState._peso(tier.price);

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null || selected,
      label: '${tier.name}, $price, $subtitle',
      excludeSemantics: true,
      child: Opacity(
        opacity: tier.isSoldOut ? 0.45 : 1,
        child: FtPressScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FtColors.progressStart.withValues(alpha: 0.34),
                        FtColors.progressStart.withValues(alpha: 0.16),
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : (t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill),
              border: Border.all(
                color: selected ? t.fieldBorderFocused : t.surfaceBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: t.titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.2,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  price,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedContainer(
                  duration: duration,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? FtColors.progressStart : Colors.transparent,
                    border: Border.all(
                      color: selected ? FtColors.progressStart : t.surfaceBorder,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: t.isDark ? t.surfaceFill.withValues(alpha: 0.75) : t.surfaceFill,
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: t.secondaryText,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: strong ? 19 : 16,
              height: 1.2,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
              color: strong ? t.titleColor : t.secondaryText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: strong ? 22 : 16,
            height: 1.2,
            fontWeight: strong ? FontWeight.w800 : (valueColor != null ? FontWeight.w700 : FontWeight.w600),
            color: valueColor ?? t.titleColor,
          ),
        ),
      ],
    );
  }
}

/// Shown while the PayMongo page is open: what to do and a link to reopen it.
class _AwaitingPaymentPanel extends StatelessWidget {
  const _AwaitingPaymentPanel({required this.onReopen});

  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FtColors.progressStart.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FtColors.progressStart.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 18, color: t.activeAccent),
              const SizedBox(width: 8),
              Text(
                'Complete your payment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: t.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A PayMongo Sandbox payment page opened in your browser. After you authorize the test payment there, you\u2019ll be brought back here automatically and your ticket will be confirmed.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: t.secondaryText,
            ),
          ),
          if (onReopen != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onReopen,
              behavior: HitTestBehavior.opaque,
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
    );
  }
}
