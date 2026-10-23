import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/subscription_plan.dart';
import '../../services/organizer_session.dart';
import '../../services/organizer_subscription_service.dart';
import '../../services/subscription_plan_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-subscription-confirmed.dart';
import 'organizer-subscription-review.dart';

/// "Choose your plan" (Mahilum design): the plans side by side, one marked
/// "Selected", and a "Continue with <plan>" button underneath.
///
/// Flow: pick a plan -> Continue -> "Confirm your subscription" review ->
/// PayMongo checkout -> wait for the server to confirm payment ->
/// [OrganizerSubscriptionConfirmedScreen]. The payment logic is unchanged;
/// only the screens in front of it are new.
class OrganizerSubscriptionPlanScreen extends StatefulWidget {
  const OrganizerSubscriptionPlanScreen({super.key});

  @override
  State<OrganizerSubscriptionPlanScreen> createState() =>
      _OrganizerSubscriptionPlanScreenState();
}

class _OrganizerSubscriptionPlanScreenState
    extends State<OrganizerSubscriptionPlanScreen> {
  /// True while a PayMongo checkout is being created or is waiting to be
  /// paid; it disables the buttons so only one payment runs at a time.
  bool _isSaving = false;

  /// The plan checkout the organizer is currently paying for, if any.
  _PendingPayment? _pending;
  bool _polling = false;

  /// The active plans from `public.subscription_plans` (admin-editable), so
  /// the price and features shown are the ones PayMongo will actually charge.
  List<SubscriptionPlan>? _plans;
  String? _plansError;
  bool _loadingPlans = true;

  /// Which plan is highlighted (`id`, or `name` for an unsaved plan).
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  String _keyOf(SubscriptionPlan plan) => plan.id ?? plan.name;

  SubscriptionPlan? get _selectedPlan {
    final plans = _plans;
    if (plans == null) return null;
    for (final plan in plans) {
      if (_keyOf(plan) == _selectedKey) return plan;
    }
    return null;
  }

  /// Current plan first, then the plan the admin badged, then the middle one.
  String? _defaultSelection(List<SubscriptionPlan> plans) {
    if (plans.isEmpty) return null;
    final current = OrganizerSession.instance.account?.subscriptionPlan;
    for (final plan in plans) {
      if (plan.name == current) return _keyOf(plan);
    }
    for (final plan in plans) {
      if (plan.hasBadge) return _keyOf(plan);
    }
    return _keyOf(plans[plans.length > 1 ? 1 : 0]);
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await SubscriptionPlanService.instance.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _plansError = null;
        _loadingPlans = false;
        _selectedKey ??= _defaultSelection(plans);
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
    final p = FairTixPalette.of(context);
    final currentPlan = OrganizerSession.instance.account?.subscriptionPlan;

    return OrganizerAuthPage(
      maxWidth: 1120,
      // Back whenever there is a screen to go back to (managing the plan from
      // Profile). On first-time onboarding this is the root, so nothing shows.
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your plan',
            textAlign: TextAlign.center,
            style: orgText(
              p,
              size: 40,
              weight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Billed monthly and renews automatically. Change plans any time.',
            textAlign: TextAlign.center,
            style: orgText(p, size: 14.5, color: p.textSecondary),
          ),
          const SizedBox(height: 32),
          if (_pending != null) ...[
            Center(child: _paymentBanner(p, _pending!)),
            const SizedBox(height: 24),
          ],
          _plansSection(p, currentPlan),
          const SizedBox(height: 28),
          Text(
            'Secure payment via PayMongo \u00b7 Instant activation \u00b7 '
            'No hidden fees',
            textAlign: TextAlign.center,
            style: orgText(p, size: 12, color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _plansSection(FairTixPalette p, String? currentPlan) {
    if (_loadingPlans) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: p.primary, strokeWidth: 2.6),
        ),
      );
    }

    final plans = _plans;
    if (plans == null || plans.isEmpty) {
      return Column(
        children: [
          Text(
            _plansError ?? 'No subscription plans are available right now.',
            textAlign: TextAlign.center,
            style: orgText(p, size: 14, color: p.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 200,
              child: OrganizerSecondaryButton(
                label: 'Try again',
                onPressed: _retryLoadPlans,
              ),
            ),
          ),
        ],
      );
    }

    final selected = _selectedPlan;
    final selectedIsCurrent = selected != null && selected.name == currentPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 24.0;
            final columns = constraints.maxWidth >= 900
                ? (plans.length < 3 ? plans.length : 3)
                : (constraints.maxWidth >= 600 ? 2 : 1);
            final cardWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final plan in plans)
                  SizedBox(
                    width: cardWidth,
                    child: _PlanCard(
                      plan: plan,
                      selected: _keyOf(plan) == _selectedKey,
                      isCurrent: plan.name == currentPlan,
                      currentNote: plan.name == currentPlan
                          ? _currentPlanNote()
                          : null,
                      onSelect: _isSaving
                          ? null
                          : () => setState(() => _selectedKey = _keyOf(plan)),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: OrganizerPrimaryButton(
              label: selected == null
                  ? 'Choose a plan'
                  : selectedIsCurrent
                  ? 'Renew ${selected.name} (+30 days)'
                  : 'Continue with ${selected.name}',
              loading: _isSaving,
              onPressed: selected == null ? null : _continue,
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the review screen; only a "Confirm Subscription" there starts the
  /// PayMongo checkout.
  Future<void> _continue() async {
    final plan = _selectedPlan;
    if (plan == null || _isSaving) return;
    final currentPlan = OrganizerSession.instance.account?.subscriptionPlan;

    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrganizerSubscriptionReviewScreen(
          plan: plan,
          isRenewal: plan.name == currentPlan,
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _selectPlan(context, _toPlanInfo(plan, currentPlan));
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

  /// "Your current plan - renews Nov 12, 2026". Renewing before that date
  /// adds 30 days to it (the server stacks same-plan renewals).
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
          content: Text(
            'Could not start the PayMongo checkout. Please try again.',
          ),
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
              'We have not received your payment yet. If you already paid, '
              'your plan will activate automatically; otherwise please try '
              'again.',
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

  Widget _paymentBanner(FairTixPalette p, _PendingPayment pending) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: OrganizerCard(
        padding: const EdgeInsets.all(20),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: p.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waiting for your ${pending.plan.name} plan payment...',
                    style: orgText(p, size: 15, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A PayMongo Sandbox payment page opened in a new tab (test mode, '
              'no real money is charged). Pay there and your plan activates '
              'automatically once the payment is confirmed.',
              style: orgText(p, size: 13, height: 1.45, color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OrganizerTextLink(
                  label: 'Reopen payment page',
                  onTap: () => _openCheckout(pending.checkoutUrl),
                ),
                const SizedBox(width: 20),
                OrganizerTextLink(label: 'Cancel', onTap: _cancelPayment),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One plan column: name, price, benefit ticks and the select button. The
/// selected card gets a purple outline, a "Selected" pill and a filled button.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.currentNote,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool isCurrent;
  final String? currentNote;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final pillText = selected ? 'Selected' : (plan.hasBadge ? plan.badge!.trim() : null);

    return MouseRegion(
      cursor: onSelect == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: OrganizerCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
          borderColor: selected ? p.accentLabel : p.border,
          borderWidth: selected ? 2 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: orgText(
                        p,
                        size: 22,
                        weight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (pillText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.progressTrack,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pillText,
                        style: orgText(
                          p,
                          size: 12,
                          weight: FontWeight.w700,
                          height: 1.2,
                          color: p.accentLabel,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.priceLabel,
                    style: orgText(
                      p,
                      size: 44,
                      weight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: -1.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      '/month',
                      style: orgText(p, size: 14, color: p.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              for (final line in plan.benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: p.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          line,
                          style: orgText(p, size: 14.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isCurrent && currentNote != null) ...[
                const SizedBox(height: 2),
                Text(
                  currentNote!,
                  style: orgText(
                    p,
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.accentLabel,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (selected)
                // Filled like the design; tapping it does nothing new.
                OrganizerPrimaryButton(label: 'Selected', onPressed: () {})
              else
                OrganizerSecondaryButton(
                  label: 'Select ${plan.name}',
                  onPressed: onSelect,
                ),
            ],
          ),
        ),
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
}
