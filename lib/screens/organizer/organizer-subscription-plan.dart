import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_colors.dart';
import '../../models/subscription_plan.dart';
import '../../services/organizer_session.dart';
import '../../services/organizer_subscription_service.dart';
import '../../services/subscription_plan_service.dart';
import 'organizer-subscription-confirmed.dart';

class OrganizerSubscriptionPlanScreen extends StatefulWidget {
  const OrganizerSubscriptionPlanScreen({super.key});

  @override
  State<OrganizerSubscriptionPlanScreen> createState() =>
      _OrganizerSubscriptionPlanScreenState();
}

class _OrganizerSubscriptionPlanScreenState
    extends State<OrganizerSubscriptionPlanScreen> {
  /// True while a PayMongo checkout is being created or is waiting to be
  /// paid; it disables every plan button so only one payment runs at a time.
  bool _isSaving = false;

  /// The plan checkout the organizer is currently paying for, if any.
  _PendingPayment? _pending;
  bool _polling = false;

  /// The active plans from `public.subscription_plans` (admin-editable), so
  /// the price and features shown are the ones PayMongo will actually charge.
  List<SubscriptionPlan>? _plans;
  String? _plansError;
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await SubscriptionPlanService.instance.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _plansError = null;
        _loadingPlans = false;
      });
    } on SubscriptionPlanException catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = null;
        _plansError = e.message;
        _loadingPlans = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plans = null;
        _plansError = 'Could not load the plans. Please try again.';
        _loadingPlans = false;
      });
    }
  }

  void _retryLoadPlans() {
    setState(() {
      _loadingPlans = true;
      _plansError = null;
    });
    _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final currentPlan = OrganizerSession.instance.account?.subscriptionPlan;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.authGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back button: shown whenever there is a screen to go back
                    // to (viewing/managing the plan from Profile). On first-time
                    // onboarding this is the root, so nothing is shown.
                    if (Navigator.of(context).canPop()) ...[
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const FairTixLogo(fontSize: 22),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Scale your events with the right tools',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 40),
                if (_pending != null) ...[
                  _paymentBanner(_pending!),
                  const SizedBox(height: 24),
                ],
                _plansSection(context, isWide, currentPlan),
                const SizedBox(height: 28),
                Text(
                  'Secure payment via PayMongo · Instant activation · No hidden fees',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The plan cards, built from the plans the admin saved. A plan with a
  /// badge (e.g. BEST VALUE) gets the highlighted style.
  Widget _plansSection(BuildContext context, bool isWide, String? currentPlan) {
    if (_loadingPlans) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final plans = _plans;
    if (plans == null || plans.isEmpty) {
      return Column(
        children: [
          Text(
            _plansError ?? 'No subscription plans are available right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _retryLoadPlans,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            child: const Text('Try again'),
          ),
        ],
      );
    }

    final cards = [
      for (final plan in plans)
        _planCard(
          context,
          _toPlanInfo(plan, currentPlan),
          highlighted: plan.hasBadge,
        ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            cards[i],
          ],
        ],
      );
    }

    // Three or fewer plans share the row; more wrap onto extra rows.
    if (cards.length <= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [for (final card in cards) SizedBox(width: 300, child: card)],
    );
  }

  _PlanInfo _toPlanInfo(SubscriptionPlan plan, String? currentPlan) =>
      _PlanInfo(
        id: plan.id,
        name: plan.name,
        price: plan.priceLabel,
        features: plan.benefits,
        badge: plan.hasBadge ? plan.badge!.trim() : null,
        isCurrent: currentPlan == plan.name,
      );

  Widget _planCard(
    BuildContext context,
    _PlanInfo plan, {
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryPurpleDarker : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.badge != null)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlighted ? Colors.white : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.price,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: highlighted ? Colors.white : AppColors.textDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 4),
                child: Text(
                  '/mo',
                  style: TextStyle(
                    fontSize: 14,
                    color: highlighted
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...plan.features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check,
                    size: 18,
                    color: highlighted ? Colors.white : AppColors.primaryPurple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        color: highlighted ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (plan.isCurrent)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _currentPlanNote(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.primaryPurple,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: highlighted
                ? ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _selectPlan(context, plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryPurpleDarker,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(plan.buttonLabel),
                  )
                : OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _selectPlan(context, plan),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.primaryPurple,
                            ),
                          )
                        : Text(plan.buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }

  /// "Current plan - renews Nov 12, 2026". Renewing before that date adds 30
  /// days to it (the server stacks same-plan renewals).
  String _currentPlanNote() {
    final renewsAt = OrganizerSession.instance.account?.subscriptionRenewsAt;
    if (renewsAt == null) return 'Your current plan';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Your current plan \u00b7 renews '
        '${months[renewsAt.month - 1]} ${renewsAt.day}, ${renewsAt.year}';
  }

  /// Starts the PayMongo checkout for [plan], opens the payment page, then
  /// waits for the server to confirm the payment before activating the plan.
  Future<void> _selectPlan(BuildContext context, _PlanInfo plan) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _isSaving = true);
    try {
      // The price is decided server-side; only the plan id (and name as a
      // fallback) is sent, never an amount.
      final checkout = await OrganizerSubscriptionService.instance
          .startCheckout(plan.name, planId: plan.id);
      if (!mounted) return;
      setState(() {
        _pending = _PendingPayment(
          plan: plan,
          checkoutUrl: checkout.checkoutUrl,
          sessionId: checkout.sessionId,
        );
      });
      await _openCheckout(checkout.checkoutUrl);
      _pollForPayment();
    } on OrganizerSubscriptionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _pending = null;
      });
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _pending = null;
      });
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Could not start the PayMongo checkout. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openCheckout(String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the payment page. Use "Reopen payment page".',
          ),
        ),
      );
    }
  }

  /// Asks the server (which asks PayMongo) whether the payment went through,
  /// every few seconds, until it is paid, fails, is canceled, or times out.
  /// The plan is activated server-side; this only reflects the result.
  Future<void> _pollForPayment() async {
    final pending = _pending;
    if (pending == null || _polling) return;
    _polling = true;
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    try {
      while (mounted &&
          _pending?.sessionId == pending.sessionId &&
          DateTime.now().isBefore(deadline)) {
        try {
          final activation = await OrganizerSubscriptionService.instance
              .confirmPayment(pending.sessionId);
          if (!mounted) return;
          setState(() {
            _pending = null;
            _isSaving = false;
          });
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrganizerSubscriptionConfirmedScreen(
                planName: activation.planName,
                price: pending.plan.price,
                renewsAt: activation.renewsAt,
                features: pending.plan.features,
              ),
            ),
          );
          return;
        } on OrganizerSubscriptionException catch (e) {
          if (!e.paymentPending) {
            if (!mounted) return;
            setState(() {
              _pending = null;
              _isSaving = false;
            });
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(e.message)));
            return;
          }
        } catch (_) {
          // Transient network error: keep waiting and try again.
        }
        await Future.delayed(const Duration(seconds: 3));
      }
      if (mounted && _pending?.sessionId == pending.sessionId) {
        setState(() {
          _pending = null;
          _isSaving = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'We have not received your payment yet. If you already paid, your '
              'plan will activate automatically; otherwise please try again.',
            ),
          ),
        );
      }
    } finally {
      _polling = false;
    }
  }

  void _cancelPayment() {
    setState(() {
      _pending = null;
      _isSaving = false;
    });
  }

  Widget _paymentBanner(_PendingPayment pending) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 640),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for your ${pending.plan.name} plan payment...',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'A PayMongo Sandbox payment page opened in a new tab (test mode, no '
            'real money is charged). Pay there and your plan activates '
            'automatically once the payment is confirmed.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _openCheckout(pending.checkoutUrl),
                child: const Text('Reopen payment page'),
              ),
              TextButton(
                onPressed: _cancelPayment,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A plan checkout that has been created on PayMongo and is awaiting payment.
class _PendingPayment {
  final _PlanInfo plan;
  final String checkoutUrl;
  final String sessionId;

  const _PendingPayment({
    required this.plan,
    required this.checkoutUrl,
    required this.sessionId,
  });
}

class _PlanInfo {
  /// `subscription_plans.plan_id`; sent to paymongo-checkout.
  final String? id;
  final String name;
  final String price;
  final List<String> features;
  final String? badge;
  final bool isCurrent;

  _PlanInfo({
    this.id,
    required this.name,
    required this.price,
    required this.features,
    this.badge,
    this.isCurrent = false,
  });

  /// The organizer's current plan can be bought again: that is a renewal.
  String get buttonLabel => isCurrent ? 'Renew Plan (+30 days)' : 'Select $name';
}
