import 'package:supabase_flutter/supabase_flutter.dart';

import 'csv_export.dart' show toSafeCsv;
import 'admin_resale_service.dart';
import 'admin_revenue_service.dart' show formatFeeRate;
import 'admin_user_service.dart' show AdminUserService, AdminUserServiceException;

/// Thrown when generating a report fails.
class AdminReportException implements Exception {
  final String message;
  const AdminReportException(this.message);
}

/// Builds the admin reports. Each report is available as rows (first row =
/// the header) so the same data can be saved as CSV (`toSafeCsv`, saved with
/// `saveCsvFile` in csv_export.dart) or as a PDF (`savePdfReport` in
/// pdf_export.dart). The `...Csv` methods are shortcuts for the CSV form.
///
/// Transactions and revenue come from the `admin_transaction_report` /
/// `admin_revenue_report` Postgres functions (supabase/report_functions.sql,
/// admin-only); refunds are read straight from `public.refunds`, which
/// admins can read via RLS.
///
/// Every method takes an optional date range: [from] inclusive, [to]
/// exclusive, either may be null for no limit on that side.
class AdminReportService {
  AdminReportService._();
  static final AdminReportService instance = AdminReportService._();

  Future<List<List<Object?>>> transactionReportRows({DateTime? from, DateTime? to}) async {
    final rows = await _rpc('admin_transaction_report', from, to);
    return [
      const [
        'Transaction ID',
        'Date',
        'Type',
        'Status',
        'Event',
        'Tier',
        'Buyer',
        'Buyer Email',
        'Seller',
        'Amount (PHP)',
        'Platform Fee (PHP)',
        'Escrow',
      ],
      for (final r in rows)
        [
          r['tx_id'],
          r['tx_date'],
          r['tx_type'],
          r['tx_status'],
          r['event_title'],
          r['tier_name'],
          r['buyer_name'],
          r['buyer_email'],
          r['seller_name'],
          r['amount'],
          r['platform_fee'],
          r['escrow'],
        ],
    ];
  }

  /// One row per event + organizer + fee rate, so the Plan and Fee Rate
  /// columns show each plan's rate. Refunded sales are excluded.
  Future<List<List<Object?>>> revenueReportRows({DateTime? from, DateTime? to}) async {
    final rows = await _rpc('admin_revenue_report', from, to);
    return [
      const [
        'Event',
        'Organizer',
        'Plan',
        'Fee Rate',
        'Tickets Sold',
        'Gross Revenue (PHP)',
        'Platform Fees (PHP)',
        'Net Payout (PHP)',
      ],
      for (final r in rows)
        [
          r['event_title'],
          r['organizer_name'],
          r['plan_name'],
          formatFeeRate((r['fee_rate'] as num).toDouble()),
          r['tickets_sold'],
          r['gross_revenue'],
          r['platform_fees'],
          r['net_payout'],
        ],
    ];
  }

  Future<List<List<Object?>>> refundReportRows({DateTime? from, DateTime? to}) async {
    try {
      var query = Supabase.instance.client.from('refunds').select('''
            refund_id, amount, reason, status, created_at, processed_at,
            provider_refund_id, provider_refunded_at,
            users(full_name, email),
            events(title)
          ''');
      if (from != null) {
        query = query.gte('created_at', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lt('created_at', to.toUtc().toIso8601String());
      }
      final rows = await query.order('created_at', ascending: false) as List;
      return [
        const [
          'Refund ID',
          'Requested',
          'Event',
          'Buyer',
          'Buyer Email',
          'Amount (PHP)',
          'Reason',
          'Status',
          'Processed',
          'PayMongo Refund ID',
          'Provider Confirmed At',
        ],
        for (final row in rows)
          () {
            final r = row as Map<String, dynamic>;
            final buyer = r['users'] as Map<String, dynamic>?;
            final event = r['events'] as Map<String, dynamic>?;
            return <Object?>[
              r['refund_id'],
              r['created_at'],
              event?['title'],
              buyer?['full_name'],
              buyer?['email'],
              r['amount'],
              r['reason'],
              r['status'] == 'processed'
                  ? 'Provider refund recorded'
                  : 'Awaiting provider confirmation',
              r['processed_at'],
              r['provider_refund_id'],
              r['provider_refunded_at'],
            ];
          }(),
      ];
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// How many eventgoers and organizers registered in the range, split by ID
  /// review status and account status. Admin accounts are not counted. The
  /// range filters on the account's creation date; with no range, all
  /// accounts are counted.
  Future<List<List<Object?>>> userRegistrationReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final users = await AdminUserService.instance.fetchUsers();
      final inRange = users.where((u) {
        if (u.role != 'buyer' && u.role != 'organizer') return false;
        if (from == null && to == null) return true;
        final at = u.createdAt;
        if (at == null) return false;
        if (from != null && at.isBefore(from)) return false;
        if (to != null && !at.isBefore(to)) return false;
        return true;
      }).toList();

      List<Object?> line(String label, Iterable<dynamic> group) {
        final list = group.toList();
        int count(bool Function(dynamic u) test) => list.where(test).length;
        return [
          label,
          list.length,
          count((u) => u.idVerificationStatus == 'verified'),
          count((u) => u.idVerificationStatus == 'pending'),
          count((u) => u.idVerificationStatus == 'rejected'),
          count((u) => u.accountStatus == 'active'),
          count((u) => u.accountStatus == 'suspended'),
          count((u) => u.accountStatus == 'deactivated'),
        ];
      }

      return [
        const [
          'Account Type',
          'Registered',
          'ID Verified / Approved',
          'Pending Review',
          'Rejected',
          'Active',
          'Suspended',
          'Deactivated',
        ],
        line('Eventgoers', inRange.where((u) => u.role == 'buyer')),
        line('Organizers', inRange.where((u) => u.role == 'organizer')),
        line('Total', inRange),
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// One row per organizer registered in the range, with the plan they hold
  /// (from `organizer_subscriptions` + `subscription_plans`), its status and
  /// dates. Organizers with no subscription show 'No plan'. The range filters
  /// on the organizer's registration date; with no range, all organizers are
  /// listed. Admins can read both tables through RLS, so no SQL is needed.
  Future<List<List<Object?>>> organizerSubscriptionReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final users = await AdminUserService.instance.fetchUsers();
      final organizers = users.where((u) {
        if (u.role != 'organizer') return false;
        if (from == null && to == null) return true;
        final at = u.createdAt;
        if (at == null) return false;
        if (from != null && at.isBefore(from)) return false;
        if (to != null && !at.isBefore(to)) return false;
        return true;
      }).toList()
        ..sort(
          (a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch),
        );

      final client = Supabase.instance.client;
      final subRows = await client
          .from('organizer_subscriptions')
          .select('user_id, plan_id, monthly_fee, start_date, end_date, status')
          as List;
      final planRows = await client
              .from('subscription_plans')
              .select('plan_id, name, monthly_fee, platform_fee_rate')
          as List;

      final planNameById = <String, String>{};
      final planNameByFee = <num, String>{};
      final planRateById = <String, num>{};
      final planRateByFee = <num, num>{};
      for (final row in planRows) {
        final r = row as Map<String, dynamic>;
        planNameById['${r['plan_id']}'] = '${r['name']}';
        final fee = r['monthly_fee'] as num?;
        final rate = r['platform_fee_rate'] as num?;
        if (rate != null) planRateById['${r['plan_id']}'] = rate;
        if (fee != null) {
          planNameByFee.putIfAbsent(fee, () => '${r['name']}');
          if (rate != null) planRateByFee.putIfAbsent(fee, () => rate);
        }
      }

      // The organizer's current subscription: an active row wins, otherwise
      // the most recently started one.
      final latest = <String, Map<String, dynamic>>{};
      for (final row in subRows) {
        final s = row as Map<String, dynamic>;
        final id = '${s['user_id']}';
        final current = latest[id];
        if (current == null) {
          latest[id] = s;
          continue;
        }
        final sActive = s['status'] == 'active';
        final cActive = current['status'] == 'active';
        if (sActive != cActive) {
          if (sActive) latest[id] = s;
        } else if ('${s['start_date']}'.compareTo('${current['start_date']}') > 0) {
          latest[id] = s;
        }
      }

      String day(DateTime? x) => x == null
          ? ''
          : '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return [
        const [
          'Organizer',
          'Organization',
          'Email',
          'Registered',
          'ID Status',
          'Plan',
          'Monthly Fee (PHP)',
          'Platform Fee Rate',
          'Plan Status',
          'Start Date',
          'End Date',
        ],
        for (final u in organizers)
          () {
            final s = latest[u.id];
            if (s == null) {
              return <Object?>[
                u.fullName,
                u.organizationName ?? '',
                u.email,
                day(u.createdAt),
                u.idVerificationStatus,
                'No plan',
                '',
                '',
                'No plan',
                '',
                '',
              ];
            }
            final fee = s['monthly_fee'] as num?;
            final planName =
                planNameById['${s['plan_id']}'] ??
                (fee == null ? null : planNameByFee[fee]) ??
                'Unknown plan';
            final rate =
                planRateById['${s['plan_id']}'] ??
                (fee == null ? null : planRateByFee[fee]);
            final end = DateTime.tryParse('${s['end_date']}');
            final status = '${s['status']}';
            final planStatus = status == 'active'
                ? ((end != null && end.isBefore(today)) ? 'Expired' : 'Active')
                : (status.isEmpty
                      ? ''
                      : status[0].toUpperCase() + status.substring(1));
            return <Object?>[
              u.fullName,
              u.organizationName ?? '',
              u.email,
              day(u.createdAt),
              u.idVerificationStatus,
              planName,
              fee,
              rate == null ? '' : formatFeeRate(rate.toDouble()),
              planStatus,
              '${s['start_date'] ?? ''}',
              '${s['end_date'] ?? ''}',
            ];
          }(),
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// Approved accounts only (`id_verification_status = 'verified'`): eventgoers
  /// first, then organizers, each with email, registration date and the date an
  /// admin approved them (`users.verified_at`, supabase/user_verified_at.sql).
  /// Organizers also get their current plan, plan status and end date. The
  /// last rows give the counts. Admin accounts are not included.
  ///
  /// The range filters on the APPROVAL date. With no range every approved
  /// account is listed, including ones whose approval date is unknown (blank);
  /// with a range those are left out because they cannot be placed in it.
  Future<List<List<Object?>>> approvedAccountsReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final users = await AdminUserService.instance.fetchUsers(onlyApproved: true);
      final approved = users.where((u) {
        if (u.role != 'buyer' && u.role != 'organizer') return false;
        if (from == null && to == null) return true;
        final at = u.verifiedAt;
        if (at == null) return false;
        if (from != null && at.isBefore(from)) return false;
        if (to != null && !at.isBefore(to)) return false;
        return true;
      }).toList()
        ..sort(
          (a, b) => (b.verifiedAt ?? epoch).compareTo(a.verifiedAt ?? epoch),
        );
      final eventgoers = approved.where((u) => u.role == 'buyer').toList();
      final organizers = approved.where((u) => u.role == 'organizer').toList();

      final client = Supabase.instance.client;
      final subRows = organizers.isEmpty
          ? <dynamic>[]
          : await client
                    .from('organizer_subscriptions')
                    .select(
                      'user_id, plan_id, monthly_fee, start_date, end_date, status',
                    )
                as List;
      final planRows = organizers.isEmpty
          ? <dynamic>[]
          : await client.from('subscription_plans').select('plan_id, name, monthly_fee')
                as List;

      final planNameById = <String, String>{};
      final planNameByFee = <num, String>{};
      for (final row in planRows) {
        final r = row as Map<String, dynamic>;
        planNameById['${r['plan_id']}'] = '${r['name']}';
        final fee = r['monthly_fee'] as num?;
        if (fee != null) planNameByFee.putIfAbsent(fee, () => '${r['name']}');
      }

      // Current subscription per organizer: an active row wins, otherwise the
      // most recently started one (same rule as the Organizer Subscription Report).
      final latest = <String, Map<String, dynamic>>{};
      for (final row in subRows) {
        final s = row as Map<String, dynamic>;
        final id = '${s['user_id']}';
        final current = latest[id];
        if (current == null) {
          latest[id] = s;
          continue;
        }
        final sActive = s['status'] == 'active';
        final cActive = current['status'] == 'active';
        if (sActive != cActive) {
          if (sActive) latest[id] = s;
        } else if ('${s['start_date']}'.compareTo('${current['start_date']}') > 0) {
          latest[id] = s;
        }
      }

      String day(DateTime? x) {
        if (x == null) return '';
        final l = x.toLocal();
        return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      List<Object?> eventgoerRow(dynamic u) => <Object?>[
        'Eventgoer',
        u.fullName,
        '',
        u.email,
        day(u.createdAt),
        day(u.verifiedAt),
        '',
        '',
        '',
      ];

      List<Object?> organizerRow(dynamic u) {
        final s = latest[u.id];
        final base = <Object?>[
          'Organizer',
          u.fullName,
          u.organizationName ?? '',
          u.email,
          day(u.createdAt),
          day(u.verifiedAt),
        ];
        if (s == null) return [...base, 'No plan', 'No plan', ''];
        final fee = s['monthly_fee'] as num?;
        final planName =
            planNameById['${s['plan_id']}'] ??
            (fee == null ? null : planNameByFee[fee]) ??
            'Unknown plan';
        final end = DateTime.tryParse('${s['end_date']}');
        final status = '${s['status']}';
        final planStatus = status == 'active'
            ? ((end != null && end.isBefore(today)) ? 'Expired' : 'Active')
            : (status.isEmpty
                  ? ''
                  : status[0].toUpperCase() + status.substring(1));
        return [...base, planName, planStatus, '${s['end_date'] ?? ''}'];
      }

      return [
        const [
          'Account Type',
          'Name',
          'Organization',
          'Email',
          'Registered',
          'Approved',
          'Plan',
          'Plan Status',
          'Plan End Date',
        ],
        for (final u in eventgoers) eventgoerRow(u),
        for (final u in organizers) organizerRow(u),
        ['Total approved eventgoers', eventgoers.length, '', '', '', '', '', '', ''],
        ['Total approved organizers', organizers.length, '', '', '', '', '', '', ''],
        ['Total approved accounts', approved.length, '', '', '', '', '', '', ''],
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// One row per event (or per day / showtime of a multi-day event) and
  /// ticket tier, with the organizer, event date and status, capacity and
  /// ticket counts. Sold, Canceled and Used are counted from the `tickets`
  /// table itself (Sold = every ticket that is not canceled), because the
  /// tier's `remaining_quantity` counter is not restored when an event is
  /// canceled; Remaining shows that counter as recorded. A multi-day
  /// event's parent record is skipped (its days carry the tiers). Drafts
  /// are not listed. The range filters on the event date; with no range all
  /// events are listed. Admins can read all four tables through RLS.
  /// A multi-day one-pass ticket is marked Used only when its status is
  /// 'used', so Used may undercount passes checked in on some days.
  Future<List<List<Object?>>> eventsAndTicketsReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final client = Supabase.instance.client;
      final users = await AdminUserService.instance.fetchUsers();
      final organizerName = <String, String>{
        for (final u in users)
          '${u.id}': (u.organizationName?.trim().isNotEmpty ?? false)
              ? u.organizationName!.trim()
              : u.fullName,
      };

      final events = await _fetchAll(
        (a, b) async =>
            (await client
                    .from('events')
                    .select(
                      'event_id, parent_event_id, day_number, start_time, '
                      'event_start_date, organizer_id, title, status',
                    )
                    .neq('status', 'draft')
                    .order('event_id')
                    .range(a, b))
                as List,
      );
      final tiers = await _fetchAll(
        (a, b) async =>
            (await client
                    .from('ticket_tiers')
                    .select(
                      'tier_id, event_id, tier_name, base_price, '
                      'total_quantity, remaining_quantity',
                    )
                    .order('tier_id')
                    .range(a, b))
                as List,
      );
      final tickets = await _fetchAll(
        (a, b) async =>
            (await client
                    .from('tickets')
                    .select('tier_id, ticket_status')
                    .order('ticket_id')
                    .range(a, b))
                as List,
      );

      final sold = <String, int>{};
      final canceled = <String, int>{};
      final used = <String, int>{};
      for (final t in tickets) {
        final id = '${t['tier_id']}';
        final status = '${t['ticket_status']}';
        if (status == 'canceled') {
          canceled[id] = (canceled[id] ?? 0) + 1;
        } else {
          sold[id] = (sold[id] ?? 0) + 1;
          if (status == 'used') used[id] = (used[id] ?? 0) + 1;
        }
      }

      final parentIds = <String>{
        for (final e in events)
          if (e['parent_event_id'] != null) '${e['parent_event_id']}',
      };
      final visible = <String, Map<String, dynamic>>{};
      for (final e in events) {
        final id = '${e['event_id']}';
        if (parentIds.contains(id)) continue;
        if (from != null || to != null) {
          final d = DateTime.tryParse('${e['event_start_date']}');
          if (d == null) continue;
          if (from != null && d.isBefore(from)) continue;
          if (to != null && !d.isBefore(to)) continue;
        }
        visible[id] = e;
      }

      final entries = <(Map<String, dynamic>, Map<String, dynamic>)>[
        for (final t in tiers)
          if (visible['${t['event_id']}'] != null)
            (visible['${t['event_id']}']!, t),
      ];
      entries.sort((a, b) {
        final byDate = '${b.$1['event_start_date']}'.compareTo(
          '${a.$1['event_start_date']}',
        );
        if (byDate != 0) return byDate;
        final byTitle = '${a.$1['title']}'.compareTo('${b.$1['title']}');
        if (byTitle != 0) return byTitle;
        final byTime = '${a.$1['start_time']}'.compareTo('${b.$1['start_time']}');
        if (byTime != 0) return byTime;
        return ((a.$2['base_price'] as num?) ?? 0).compareTo(
          (b.$2['base_price'] as num?) ?? 0,
        );
      });

      var totalCapacity = 0;
      var totalSold = 0;
      var totalCanceled = 0;
      var totalUsed = 0;
      var totalRemaining = 0;
      final body = <List<Object?>>[];
      for (final (e, t) in entries) {
        final tierId = '${t['tier_id']}';
        final capacity = (t['total_quantity'] as num?)?.toInt() ?? 0;
        final remaining = (t['remaining_quantity'] as num?)?.toInt() ?? 0;
        final soldCount = sold[tierId] ?? 0;
        final canceledCount = canceled[tierId] ?? 0;
        final usedCount = used[tierId] ?? 0;
        totalCapacity += capacity;
        totalSold += soldCount;
        totalCanceled += canceledCount;
        totalUsed += usedCount;
        totalRemaining += remaining;
        final time = e['start_time'] == null ? '' : '${e['start_time']}';
        body.add(<Object?>[
          e['title'],
          e['day_number'] ?? '',
          time.length >= 5 ? time.substring(0, 5) : time,
          organizerName['${e['organizer_id']}'] ?? '',
          e['event_start_date'],
          _capitalize('${e['status']}'),
          t['tier_name'],
          t['base_price'],
          capacity,
          soldCount,
          canceledCount,
          usedCount,
          remaining,
        ]);
      }

      return [
        const [
          'Event',
          'Day',
          'Start Time',
          'Organizer',
          'Event Date',
          'Event Status',
          'Tier',
          'Price (PHP)',
          'Capacity',
          'Sold',
          'Canceled',
          'Used',
          'Remaining',
        ],
        ...body,
        if (body.isNotEmpty)
          [
            'Total',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            totalCapacity,
            totalSold,
            totalCanceled,
            totalUsed,
            totalRemaining,
          ],
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// Every QR scan attempt in the range (newest first): event, day, session,
  /// scan time, result and ticket tier. The QR token, device info and ticket
  /// holder are NOT exported. The range filters on the scan time; with no
  /// range every scan is listed. The last rows give the counts. Admins can
  /// read `qr_scan_logs`, `scanner_sessions`, `events`, `tickets` and
  /// `ticket_tiers` through RLS, so no SQL is needed.
  Future<List<List<Object?>>> scannerActivityReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final client = Supabase.instance.client;
      final logs = await _fetchAll((a, b) async {
        var query = client.from('qr_scan_logs').select(
          'log_id, scan_result, scanned_at, session_id, '
          'scanner_sessions(events(title, event_start_date, day_number)), '
          'tickets(ticket_tiers(tier_name))',
        );
        if (from != null) {
          query = query.gte('scanned_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          query = query.lt('scanned_at', to.toUtc().toIso8601String());
        }
        return (await query
                .order('scanned_at', ascending: false)
                .order('log_id')
                .range(a, b))
            as List;
      });

      const resultLabels = {
        'valid': 'Accepted',
        'already_used': 'Rejected - already used',
        'invalid': 'Rejected - invalid ticket',
        'wrong_event': 'Rejected - wrong event',
      };
      String stamp(Object? value) {
        final at = DateTime.tryParse('$value')?.toLocal();
        if (at == null) return '';
        String two(int n) => n.toString().padLeft(2, '0');
        return '${at.year}-${two(at.month)}-${two(at.day)} '
            '${two(at.hour)}:${two(at.minute)}';
      }

      var accepted = 0;
      final body = <List<Object?>>[];
      for (final log in logs) {
        final session = _asMap(log['scanner_sessions']);
        final event = _asMap(session?['events']);
        final tier = _asMap(_asMap(log['tickets'])?['ticket_tiers']);
        final result = '${log['scan_result']}';
        if (result == 'valid') accepted++;
        final sessionId = '${log['session_id']}';
        body.add(<Object?>[
          event?['title'] ?? '',
          event?['day_number'] ?? '',
          event?['event_start_date'] ?? '',
          sessionId.length >= 8 ? sessionId.substring(0, 8) : sessionId,
          stamp(log['scanned_at']),
          resultLabels[result] ?? result,
          tier?['tier_name'] ?? '',
        ]);
      }

      return [
        const [
          'Event',
          'Day',
          'Event Date',
          'Session',
          'Scanned At',
          'Result',
          'Ticket Tier',
        ],
        ...body,
        if (body.isNotEmpty) ...[
          ['Total scans', body.length, '', '', '', '', ''],
          ['Accepted', accepted, '', '', '', '', ''],
          ['Rejected', body.length - accepted, '', '', '', '', ''],
        ],
      ];
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// With [approvedOnly] the detail rows are limited to approved accounts
  /// (`id_verification_status = 'verified'`). The summary rows at the bottom
  /// always count the eventgoers and organizers (admins are not counted) of
  /// the WHOLE selected range, so they ignore [approvedOnly].
  ///
  /// Every account of every role (eventgoer, organizer, admin), including
  /// pending and rejected ones: account ID, name, email, role, registration
  /// date, ID verification status and account status, newest first, with a
  /// total row. The range filters on the registration date; with no range
  /// all accounts are listed (accounts with no creation date only then).
  Future<List<List<Object?>>> userAccountsReportRows({
    DateTime? from,
    DateTime? to,
    bool approvedOnly = false,
  }) async {
    try {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final users = await AdminUserService.instance.fetchUsers();
      final inRange = users.where((u) {
        if (from == null && to == null) return true;
        final at = u.createdAt;
        if (at == null) return false;
        if (from != null && at.isBefore(from)) return false;
        if (to != null && !at.isBefore(to)) return false;
        return true;
      }).toList()
        ..sort(
          (a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch),
        );

      String role(String r) => switch (r) {
        'buyer' => 'Eventgoer',
        'organizer' => 'Organizer',
        'admin' => 'Admin',
        _ => r,
      };
      String verification(String s) => switch (s) {
        'verified' => 'Approved',
        'pending' => 'Pending',
        'rejected' => 'Rejected',
        _ => s,
      };

      final detail = approvedOnly
          ? inRange.where((u) => u.idVerificationStatus == 'verified').toList()
          : inRange;

      // Summary: eventgoers and organizers in the whole selected range
      // (not affected by approvedOnly; admin accounts are not counted).
      final counted = inRange
          .where((u) => u.role == 'buyer' || u.role == 'organizer')
          .toList();
      int count(bool Function(dynamic u) test) => counted.where(test).length;
      List<Object?> summary(String label, int n) => [
        label,
        n,
        '',
        '',
        '',
        '',
        '',
        '',
      ];

      return [
        const [
          'Account ID',
          'Name',
          'Email',
          'Role',
          'Registered',
          'Verification Status',
          'Approved On',
          'Account Status',
        ],
        for (final u in detail)
          [
            u.id,
            u.fullName,
            u.email,
            role(u.role),
            _formatDay(u.createdAt),
            verification(u.idVerificationStatus),
            _formatDay(u.verifiedAt),
            _capitalize(u.accountStatus),
          ],
        if (detail.isNotEmpty)
          [
            approvedOnly ? 'Total approved accounts listed' : 'Total accounts',
            detail.length,
            '',
            '',
            '',
            '',
            '',
            '',
          ],
        if (counted.isNotEmpty) ...[
          summary(
            'Summary: eventgoers and organizers registered in the selected range (ignores "Approved only"; admins not counted)',
            counted.length,
          ),
          summary('Eventgoers', count((u) => u.role == 'buyer')),
          summary('Organizers', count((u) => u.role == 'organizer')),
          summary(
            'Approved',
            count((u) => u.idVerificationStatus == 'verified'),
          ),
          summary(
            'Pending',
            count((u) => u.idVerificationStatus == 'pending'),
          ),
          summary(
            'Rejected',
            count((u) => u.idVerificationStatus == 'rejected'),
          ),
          summary('Active', count((u) => u.accountStatus == 'active')),
          summary('Suspended', count((u) => u.accountStatus == 'suspended')),
          summary(
            'Deactivated',
            count((u) => u.accountStatus == 'deactivated'),
          ),
        ],
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// Every fraud alert / price flag (newest first): type, source, severity,
  /// status, created date, flagged user, event, who reviewed it, when, and the
  /// resolution note. Read from `fraud_alerts` (admin-only RLS, see
  /// supabase/fraud_alerts.sql). The range filters on the created date.
  Future<List<List<Object?>>> fraudAlertsReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final client = Supabase.instance.client;
      final users = await AdminUserService.instance.fetchUsers();
      final nameById = <String, String>{
        for (final u in users) '${u.id}': u.fullName,
      };
      final alerts = await _fetchAll((a, b) async {
        var query = client.from('fraud_alerts').select(
          'alert_id, alert_type, source, severity, status, user_id, event_id, '
          'ticket_id, listing_id, details, created_at, reviewed_by, '
          'reviewed_at, resolution_note, users(full_name, email), events(title)',
        );
        if (from != null) {
          query = query.gte('created_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          query = query.lt('created_at', to.toUtc().toIso8601String());
        }
        return (await query
                .order('created_at', ascending: false)
                .order('alert_id')
                .range(a, b))
            as List;
      });

      return [
        const [
          'Alert ID',
          'Type',
          'Source',
          'Severity',
          'Status',
          'Created',
          'Flagged User',
          'Flagged User Email',
          'Event',
          'Reviewed By',
          'Reviewed At',
          'Resolution Note',
        ],
        for (final row in alerts)
          () {
            final alert = FraudAlertEntry.fromRow(row);
            final reviewer = row['reviewed_by'];
            return <Object?>[
              alert.id,
              alert.typeLabel,
              alert.sourceLabel,
              alert.severityLabel,
              alert.statusLabel,
              _formatStamp(alert.createdAt),
              alert.userName ?? '',
              alert.userEmail ?? '',
              alert.eventTitle ?? '',
              reviewer == null ? '' : (nameById['$reviewer'] ?? 'Unknown admin'),
              _formatStamp(alert.reviewedAt),
              alert.resolutionNote ?? '',
            ];
          }(),
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// The Resale Activity report: every listing in the range (same columns as
  /// the Resale Monitoring export) plus the Buyer and Buyer Email of sold
  /// listings. A listing does not store its buyer, so the buyer is the
  /// `buyer_id` of the resale transaction for the same ticket and seller whose
  /// time is closest to the listing's sold time (failed and pending
  /// transactions are ignored). Left blank when no transaction matches.
  /// The range filters on the listed date.
  Future<List<List<Object?>>> resaleActivityReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final listings = await AdminResaleService.instance.fetchListings();
      final inRange = listings.where((l) {
        if (from != null && l.listedAt.isBefore(from)) return false;
        if (to != null && !l.listedAt.isBefore(to)) return false;
        return true;
      }).toList();

      final buyers = <String, ({String name, String email})>{};
      final sold = inRange
          .where((l) => l.status == 'sold' && l.soldAt != null)
          .toList();
      if (sold.isNotEmpty) {
        final client = Supabase.instance.client;
        final users = await AdminUserService.instance.fetchUsers();
        final userById = {for (final u in users) '${u.id}': u};
        final txs = await _fetchAll(
          (a, b) async =>
              (await client
                      .from('transactions')
                      .select('ticket_id, buyer_id, seller_id, status, created_at')
                      .eq('transaction_type', 'resale')
                      .order('transaction_id')
                      .range(a, b))
                  as List,
        );
        final byTicket = <String, List<Map<String, dynamic>>>{};
        for (final t in txs) {
          final status = '${t['status']}';
          if (status == 'failed' || status == 'pending') continue;
          byTicket.putIfAbsent('${t['ticket_id']}', () => []).add(t);
        }
        for (final l in sold) {
          Map<String, dynamic>? best;
          Duration? bestGap;
          for (final t in byTicket[l.ticketId] ?? const <Map<String, dynamic>>[]) {
            if ('${t['seller_id']}' != l.sellerId) continue;
            final at = DateTime.tryParse('${t['created_at']}');
            if (at == null) continue;
            final gap = at.difference(l.soldAt!).abs();
            if (bestGap == null || gap < bestGap) {
              best = t;
              bestGap = gap;
            }
          }
          final buyer = best == null ? null : userById['${best['buyer_id']}'];
          if (buyer != null) {
            buyers[l.id] = (name: buyer.fullName, email: buyer.email);
          }
        }
      }
      return resaleListingsToRows(inRange, buyers: buyers);
    } on AdminResaleException catch (e) {
      throw AdminReportException(e.message);
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// The application review history (newest first), one row per step from
  /// `account_reviews` (supabase/audit_log.sql): applicant, email, applicant
  /// type, step (Submitted / Approved / Rejected / Resubmitted / Reopened),
  /// rejection reason, the admin who acted, and the date. History starts when
  /// audit_log.sql was installed, plus approvals backfilled from
  /// `users.verified_at`: earlier rejections, submissions and all reasons
  /// from before admin_review_account.sql was installed are blank/missing.
  /// The range filters on the step date.
  Future<List<List<Object?>>> applicationReviewsReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final client = Supabase.instance.client;
      final users = await AdminUserService.instance.fetchUsers();
      final nameById = <String, String>{
        for (final u in users) '${u.id}': u.fullName,
      };
      final reviews = await _fetchAll((a, b) async {
        var query = client.from('account_reviews').select(
          'review_id, applicant_type, action, reason, actor_id, created_at, '
          'users(full_name, email)',
        );
        if (from != null) {
          query = query.gte('created_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          query = query.lt('created_at', to.toUtc().toIso8601String());
        }
        return (await query
                .order('created_at', ascending: false)
                .order('review_id')
                .range(a, b))
            as List;
      });

      return [
        const [
          'Date',
          'Applicant',
          'Email',
          'Applicant Type',
          'Step',
          'Reason',
          'Admin',
        ],
        for (final r in reviews)
          () {
            final applicant = _asMap(r['users']);
            final actor = r['actor_id'];
            return <Object?>[
              _formatStamp(DateTime.tryParse('${r['created_at']}')),
              applicant?['full_name'] ?? '',
              applicant?['email'] ?? '',
              _capitalize('${r['applicant_type']}'),
              _capitalize('${r['action']}'),
              r['reason'] ?? '',
              actor == null ? '' : (nameById['$actor'] ?? 'Unknown admin'),
            ];
          }(),
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException(_auditTableError(e));
    }
  }

  /// What admins did (newest first), from `admin_audit_log`
  /// (supabase/audit_log.sql): date, admin, action, target type, target and
  /// details. Admin is blank when no signed-in user was involved (for example
  /// a change made in the SQL Editor). Covers approvals and rejections,
  /// suspensions and reactivations, role changes, fraud-alert reviews, resale
  /// listings taken down, events canceled or unpublished by an admin and
  /// refund status changes. NOT covered: announcements and subscription-plan
  /// or platform-settings edits, and anything before audit_log.sql was
  /// installed. The range filters on the date.
  Future<List<List<Object?>>> adminAuditLogReportRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final client = Supabase.instance.client;
      final users = await AdminUserService.instance.fetchUsers();
      final nameById = <String, String>{
        for (final u in users) '${u.id}': u.fullName,
      };
      final entries = await _fetchAll((a, b) async {
        var query = client.from('admin_audit_log').select(
          'log_id, actor_id, action, target_type, target_id, target_label, '
          'details, created_at',
        );
        if (from != null) {
          query = query.gte('created_at', from.toUtc().toIso8601String());
        }
        if (to != null) {
          query = query.lt('created_at', to.toUtc().toIso8601String());
        }
        return (await query
                .order('created_at', ascending: false)
                .order('log_id')
                .range(a, b))
            as List;
      });

      return [
        const ['Date', 'Admin', 'Action', 'Target Type', 'Target', 'Details'],
        for (final e in entries)
          <Object?>[
            _formatStamp(DateTime.tryParse('${e['created_at']}')),
            e['actor_id'] == null
                ? ''
                : (nameById['${e['actor_id']}'] ?? 'Unknown admin'),
            _capitalize('${e['action']}'.replaceAll('_', ' ')),
            _capitalize('${e['target_type']}'.replaceAll('_', ' ')),
            e['target_label'] ?? '',
            e['details'] ?? '',
          ],
      ];
    } on AdminUserServiceException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    } on PostgrestException catch (e) {
      throw AdminReportException(_auditTableError(e));
    }
  }

  /// PGRST205 / 42P01 = the table does not exist yet: audit_log.sql has not
  /// been run on this Supabase project.
  String _auditTableError(PostgrestException e) {
    if (e.code == 'PGRST205' || e.code == '42P01') {
      return 'Could not generate the report: run supabase/audit_log.sql in the Supabase SQL Editor first.';
    }
    return 'Could not generate the report: ${e.message}';
  }

  /// yyyy-MM-dd in the device's local time, or '' when unknown.
  String _formatDay(DateTime? at) {
    if (at == null) return '';
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  /// yyyy-MM-dd HH:mm in the device's local time, or '' when unknown.
  String _formatStamp(DateTime? at) {
    if (at == null) return '';
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_formatDay(l)} ${two(l.hour)}:${two(l.minute)}';
  }

  /// Supabase returns at most 1,000 rows per request, so this reads a table
  /// page by page. [page] must use a stable, unique sort order.
  Future<List<Map<String, dynamic>>> _fetchAll(
    Future<List<dynamic>> Function(int from, int to) page,
  ) async {
    const size = 1000;
    final out = <Map<String, dynamic>>[];
    for (var start = 0; ; start += size) {
      final rows = await page(start, start + size - 1);
      out.addAll(rows.cast<Map<String, dynamic>>());
      if (rows.length < size) break;
    }
    return out;
  }

  /// An embedded relation comes back as a map (many-to-one) or, rarely, a
  /// one-item list; this returns the map either way.
  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
      return value.first as Map<String, dynamic>;
    }
    return null;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<String> transactionReportCsv({DateTime? from, DateTime? to}) async =>
      toSafeCsv(await transactionReportRows(from: from, to: to));

  Future<String> revenueReportCsv({DateTime? from, DateTime? to}) async =>
      toSafeCsv(await revenueReportRows(from: from, to: to));

  Future<String> refundReportCsv({DateTime? from, DateTime? to}) async =>
      toSafeCsv(await refundReportRows(from: from, to: to));

  Future<List<Map<String, dynamic>>> _rpc(
    String function,
    DateTime? from,
    DateTime? to,
  ) async {
    try {
      final rows =
          await Supabase.instance.client.rpc(
                function,
                params: {
                  'p_from': from?.toUtc().toIso8601String(),
                  'p_to': to?.toUtc().toIso8601String(),
                },
              )
              as List;
      return rows.cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }
}
