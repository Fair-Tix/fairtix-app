import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../services/organizer_session.dart';
import '../../services/organizer_subscription_service.dart';
import 'organizer-subscription-confirmed.dart';

class OrganizerSubscriptionPlanScreen extends StatefulWidget {
  const OrganizerSubscriptionPlanScreen({super.key});

  @override
  State<OrganizerSubscriptionPlanScreen> createState() =>
      _OrganizerSubscriptionPlanScreenState();
}

class _OrganizerSubscriptionPlanScreenState
    extends State<OrganizerSubscriptionPlanScreen> {
  bool _isSaving = false;

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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FairTixLogo(fontSize: 22),
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
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _planCard(context, _basicPlan(currentPlan)),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _planCard(
                              context,
                              _standardPlan(currentPlan),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _planCard(
                              context,
                              _premiumPlan(currentPlan),
                              highlighted: true,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _planCard(context, _basicPlan(currentPlan)),
                          const SizedBox(height: 20),
                          _planCard(context, _standardPlan(currentPlan)),
                          const SizedBox(height: 20),
                          _planCard(
                            context,
                            _premiumPlan(currentPlan),
                            highlighted: true,
                          ),
                        ],
                      ),
                const SizedBox(height: 28),
                Text(
                  'Cancel anytime · Instant activation · No hidden fees',
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

  _PlanInfo _basicPlan(String? currentPlan) => _PlanInfo(
    name: 'Basic',
    price: '\u20B1299',
    features: const [
      'Up to 3 events/month',
      'Max 500 tickets/event',
      '8% platform fee/ticket',
      'Unlimited scanner sessions',
    ],
    isCurrent: currentPlan == 'Basic',
  );

  _PlanInfo _standardPlan(String? currentPlan) => _PlanInfo(
    name: 'Standard',
    price: '\u20B1699',
    features: const [
      'Up to 9 events/month',
      'Max 5,000 tickets/event',
      '9% platform fee/ticket',
      'Unlimited scanner sessions',
      'CSV export & analytics',
    ],
    isCurrent: currentPlan == 'Standard',
  );

  _PlanInfo _premiumPlan(String? currentPlan) => _PlanInfo(
    name: 'Premium',
    price: '\u20B11,499',
    badge: 'BEST VALUE',
    features: const [
      'Unlimited events',
      'Unlimited ticket capacity',
      '10% platform fee/ticket',
      'Unlimited scanner sessions',
      'CSV export & enhanced analytics',
    ],
    isCurrent: currentPlan == 'Premium',
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
          SizedBox(
            width: double.infinity,
            height: 46,
            child: plan.isCurrent
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Current Plan',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : highlighted
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
                        : Text('Select ${plan.name}'),
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
                        : Text('Select ${plan.name}'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPlan(BuildContext context, _PlanInfo plan) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _isSaving = true);
    try {
      final renewsAt = await OrganizerSubscriptionService.instance.selectPlan(
        plan.name,
      );
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => OrganizerSubscriptionConfirmedScreen(
            planName: plan.name,
            price: plan.price,
            renewsAt: renewsAt,
          ),
        ),
      );
    } on OrganizerSubscriptionException catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PlanInfo {
  final String name;
  final String price;
  final List<String> features;
  final String? badge;
  final bool isCurrent;

  _PlanInfo({
    required this.name,
    required this.price,
    required this.features,
    this.badge,
    this.isCurrent = false,
  });
}
