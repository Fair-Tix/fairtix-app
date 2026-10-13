import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when loading or processing refunds fails.
class AdminRefundException implements Exception {
  final String message;
  const AdminRefundException(this.message);
}

/// One row of the admin refund log (`public.refunds`, see
/// supabase/refund_functions.sql).
class RefundEntry {
  const RefundEntry({
    required this.id,
    required this.eventTitle,
    required this.buyerName,
    required this.buyerEmail,
    required this.amount,
    required this.reason,
    required this.isProcessed,
    required this.createdAt,
    this.processedAt,
  });

  final String id;
  final String eventTitle;
  final String buyerName;
  final String buyerEmail;
  final double amount;
  final String reason;
  final bool isProcessed;
  final DateTime createdAt;
  final DateTime? processedAt;

  String get statusLabel => isProcessed ? 'Processed' : 'Pending';

  factory RefundEntry.fromRow(Map<String, dynamic> row) {
    final buyer = row['users'] as Map<String, dynamic>?;
    final event = row['events'] as Map<String, dynamic>?;
    final processedAt = row['processed_at'] as String?;
    return RefundEntry(
      id: row['refund_id'] as String,
      eventTitle: (event?['title'] as String?) ?? 'Unknown event',
      buyerName: (buyer?['full_name'] as String?) ?? 'Unknown buyer',
      buyerEmail: (buyer?['email'] as String?) ?? '',
      amount: (row['amount'] as num).toDouble(),
      reason: (row['reason'] as String?) ?? '',
      isProcessed: row['status'] == 'processed',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      processedAt: processedAt == null
          ? null
          : DateTime.parse(processedAt).toLocal(),
    );
  }
}

/// Admin view of the refund log. Reads `public.refunds` (admins can read
/// every row via RLS) and marks refunds processed through the
/// `admin_process_refund` Postgres function.
class AdminRefundService {
  AdminRefundService._();
  static final AdminRefundService instance = AdminRefundService._();

  /// Newest first.
  Future<List<RefundEntry>> fetchRefunds() async {
    try {
      final rows = await Supabase.instance.client
          .from('refunds')
          .select('''
            refund_id, amount, reason, status, created_at, processed_at,
            users(full_name, email),
            events(title)
          ''')
          .order('created_at', ascending: false) as List;
      return rows
          .map((row) => RefundEntry.fromRow(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminRefundException('Could not load the refund log: ${e.message}');
    }
  }

  Future<void> markProcessed(String refundId) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_process_refund',
        params: {'p_refund_id': refundId},
      );
    } on PostgrestException catch (e) {
      throw AdminRefundException('Could not process the refund: ${e.message}');
    }
  }
}
