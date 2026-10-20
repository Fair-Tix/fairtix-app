/// One organizer subscription plan, as saved by the admin in
/// Platform Settings (`public.subscription_plans`, supabase/subscription_plans.sql).
///
/// The numeric fields are what the server enforces (price charged through
/// PayMongo, platform fee on primary sales, event/ticket/multi-day limits,
/// report export). [benefits] is the list of lines shown on the plan card.
/// A null limit means unlimited.
class SubscriptionPlan {
  /// Null for a plan the admin has added but not saved yet.
  final String? id;
  final String name;
  final double monthlyFee;

  /// Fraction of each primary sale kept by FairTix (0.08 = 8%).
  final double feeRate;
  final int? maxEventsPerMonth;
  final int? maxTicketsPerDay;
  final int? maxMultiDayDays;
  final bool canExport;
  final List<String> benefits;

  /// Short ribbon on the card (e.g. "BEST VALUE"); null or empty for none.
  final String? badge;
  final bool isActive;

  const SubscriptionPlan({
    this.id,
    required this.name,
    required this.monthlyFee,
    required this.feeRate,
    this.maxEventsPerMonth,
    this.maxTicketsPerDay,
    this.maxMultiDayDays,
    this.canExport = false,
    this.benefits = const [],
    this.badge,
    this.isActive = true,
  });

  factory SubscriptionPlan.fromRow(Map<String, dynamic> row) {
    return SubscriptionPlan(
      id: row['plan_id'] as String?,
      name: (row['name'] as String?) ?? '',
      monthlyFee: (row['monthly_fee'] as num?)?.toDouble() ?? 0,
      feeRate: (row['platform_fee_rate'] as num?)?.toDouble() ?? 0,
      maxEventsPerMonth: (row['max_events_per_month'] as num?)?.toInt(),
      maxTicketsPerDay: (row['max_tickets_per_day'] as num?)?.toInt(),
      maxMultiDayDays: (row['max_multiday_days'] as num?)?.toInt(),
      canExport: (row['can_export'] as bool?) ?? false,
      benefits: [
        for (final line in (row['benefits'] as List?) ?? const [])
          line.toString(),
      ],
      badge: row['badge'] as String?,
      isActive: (row['is_active'] as bool?) ?? true,
    );
  }

  /// The shape `admin_save_subscription_plans` expects.
  Map<String, dynamic> toJson() => {
    'plan_id': id,
    'name': name,
    'monthly_fee': monthlyFee,
    'platform_fee_rate': feeRate,
    'max_events_per_month': maxEventsPerMonth,
    'max_tickets_per_day': maxTicketsPerDay,
    'max_multiday_days': maxMultiDayDays,
    'can_export': canExport,
    'benefits': benefits,
    'badge': badge,
    'is_active': isActive,
  };

  /// "₱299" / "₱1,499" / "₱299.50".
  String get priceLabel => formatPlanPrice(monthlyFee);

  bool get hasBadge => badge != null && badge!.trim().isNotEmpty;
}

/// "₱1,499" for whole amounts, "₱299.50" otherwise.
String formatPlanPrice(num amount) {
  final isWhole = amount == amount.roundToDouble();
  final fixed = amount.abs().toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₱$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}
