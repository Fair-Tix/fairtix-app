import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when loading the admin overview numbers fails.
class AdminOverviewException implements Exception {
  final String message;
  const AdminOverviewException(this.message);
}

/// Headline numbers for the admin dashboard cards.
class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.totalOrganizers,
    required this.totalEvents,
    required this.ticketsSold,
    required this.platformRevenue,
  });

  final int totalUsers;
  final int totalOrganizers;
  final int totalEvents;
  final int ticketsSold;
  final double platformRevenue;
}

/// One day of platform revenue.
class DailyRevenue {
  const DailyRevenue({
    required this.day,
    required this.tickets,
    required this.gross,
    required this.fees,
  });

  final DateTime day;
  final int tickets;
  final double gross;
  final double fees;
}

/// One month of platform revenue.
class MonthlyRevenue {
  const MonthlyRevenue({
    required this.month,
    required this.tickets,
    required this.gross,
    required this.fees,
    required this.net,
  });

  /// 1 = January ... 12 = December.
  final int month;
  final int tickets;
  final double gross;
  final double fees;
  final double net;

  bool get hasSales => tickets > 0;
}

/// Admin dashboard and revenue-chart data, backed by the
/// `admin_dashboard_stats` / `admin_revenue_daily` / `admin_revenue_monthly`
/// Postgres functions (supabase/admin_overview_functions.sql). The functions
/// return only periods that had sales; this class fills in the zero days and
/// months so charts always have a complete axis.
class AdminOverviewService {
  AdminOverviewService._();
  static final AdminOverviewService instance = AdminOverviewService._();

  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final rows = await Supabase.instance.client.rpc('admin_dashboard_stats') as List;
      final row = rows.first as Map<String, dynamic>;
      return DashboardStats(
        totalUsers: (row['total_users'] as num).toInt(),
        totalOrganizers: (row['total_organizers'] as num).toInt(),
        totalEvents: (row['total_events'] as num).toInt(),
        ticketsSold: (row['tickets_sold'] as num).toInt(),
        platformRevenue: (row['platform_revenue'] as num).toDouble(),
      );
    } on PostgrestException catch (e) {
      throw AdminOverviewException(_friendly(e, 'dashboard statistics'));
    }
  }

  /// The last [days] days including today, oldest first.
  Future<List<DailyRevenue>> fetchDaily({int days = 30}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (days - 1));
    final end = DateTime(now.year, now.month, now.day + 1);
    try {
      final rows = await Supabase.instance.client.rpc(
        'admin_revenue_daily',
        params: {
          'p_from': start.toUtc().toIso8601String(),
          'p_to': end.toUtc().toIso8601String(),
        },
      ) as List;

      final byDay = <String, Map<String, dynamic>>{
        for (final raw in rows)
          _key(DateTime.parse((raw as Map<String, dynamic>)['sale_date'] as String)): raw,
      };

      return [
        for (var i = 0; i < days; i++)
          () {
            final day = DateTime(start.year, start.month, start.day + i);
            final row = byDay[_key(day)];
            return DailyRevenue(
              day: day,
              tickets: (row?['tickets'] as num?)?.toInt() ?? 0,
              gross: (row?['gross'] as num?)?.toDouble() ?? 0,
              fees: (row?['fees'] as num?)?.toDouble() ?? 0,
            );
          }(),
      ];
    } on PostgrestException catch (e) {
      throw AdminOverviewException(_friendly(e, 'daily revenue'));
    }
  }

  /// All 12 months of [year], January first.
  Future<List<MonthlyRevenue>> fetchMonthly(int year) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'admin_revenue_monthly',
        params: {'p_year': year},
      ) as List;

      final byMonth = <int, Map<String, dynamic>>{
        for (final raw in rows)
          ((raw as Map<String, dynamic>)['month_no'] as num).toInt(): raw,
      };

      return [
        for (var m = 1; m <= 12; m++)
          MonthlyRevenue(
            month: m,
            tickets: (byMonth[m]?['tickets'] as num?)?.toInt() ?? 0,
            gross: (byMonth[m]?['gross'] as num?)?.toDouble() ?? 0,
            fees: (byMonth[m]?['fees'] as num?)?.toDouble() ?? 0,
            net: (byMonth[m]?['net'] as num?)?.toDouble() ?? 0,
          ),
      ];
    } on PostgrestException catch (e) {
      throw AdminOverviewException(_friendly(e, 'monthly revenue'));
    }
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String _friendly(PostgrestException e, String what) {
    // PGRST202: the function doesn't exist yet in this Supabase project.
    if (e.code == 'PGRST202') {
      return 'Could not load $what: run supabase/admin_overview_functions.sql in the Supabase SQL Editor first.';
    }
    return 'Could not load $what: ${e.message}';
  }
}
