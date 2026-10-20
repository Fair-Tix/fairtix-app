import 'package:flutter/material.dart';

/// Formats a DateTime like "June 27, 2026 • 9:41 AM" without pulling in
/// the intl package.
String formatDateTime(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} \u2022 $hour12:$minute $period';
}

enum TransactionCategory { ticketPurchase, resalePurchase, resaleSale, refund }

enum TransactionStatus { completed, pending, failed, refunded }

/// A payment transaction (ticket purchase, resale purchase, resale sale,
/// or refund), built from the rows returned by the `get_my_transactions()`
/// Postgres function (see supabase/my_transactions.sql and
/// services/transaction_repository.dart).
class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.eventTitle,
    required this.tierName,
    required this.category,
    required this.amount,
    required this.dateTime,
    required this.paymentMethod,
    this.status = TransactionStatus.completed,
    this.subtotal,
    this.platformFee,
    this.ticketId,
  });

  final String id;
  final String eventTitle;
  final String tierName;
  final TransactionCategory category;

  /// Total amount paid (ticket/resale purchases) or received (resale sale).
  final double amount;
  final DateTime dateTime;
  final String paymentMethod;
  final TransactionStatus status;

  /// Ticket/resale price before the platform fee, when applicable.
  final double? subtotal;
  final double? platformFee;

  /// Id of the related ticket in `sampleMyTickets`, when this transaction
  /// is tied to a specific ticket (purchase, resale purchase, or sale).
  /// Lets a ticket-sold notification deep-link straight to its receipt.
  final String? ticketId;

  String get referenceNumber => 'FTX-${id.toUpperCase()}';

  /// True for money the user received (a resale sale or a refund); false
  /// for money paid.
  bool get isCredit =>
      category == TransactionCategory.resaleSale || category == TransactionCategory.refund;

  String get categoryLabel => switch (category) {
        TransactionCategory.ticketPurchase => 'Ticket Purchase',
        TransactionCategory.resalePurchase => 'Resale Purchase',
        TransactionCategory.resaleSale => 'Resale Sale',
        TransactionCategory.refund => 'Refund',
      };

  IconData get categoryIcon => switch (category) {
        TransactionCategory.ticketPurchase => Icons.confirmation_number_rounded,
        TransactionCategory.resalePurchase => Icons.swap_horiz_rounded,
        TransactionCategory.resaleSale => Icons.sell_rounded,
        TransactionCategory.refund => Icons.undo_rounded,
      };

  String get statusLabel => switch (status) {
        TransactionStatus.completed => 'Completed',
        TransactionStatus.pending => 'Pending',
        TransactionStatus.failed => 'Failed',
        TransactionStatus.refunded => 'Refunded',
      };

  /// Builds an [AppTransaction] from a flat row returned by
  /// `get_my_transactions()` (columns: transaction_id, ticket_id,
  /// buyer_id, seller_id, transaction_type, amount, platform_fee, status,
  /// created_at, tier_name, event_title). [currentUserId] is needed to tell
  /// a resale sale (money received, this user is the seller) apart from a
  /// resale purchase (money paid, this user is the buyer). Refund rows
  /// arrive with transaction_type = 'refund'.
  factory AppTransaction.fromRow(Map<String, dynamic> row, {required String currentUserId}) {
    final isSeller = row['seller_id'] == currentUserId;
    final rawType = row['transaction_type'] as String;
    final category = rawType == 'refund'
        ? TransactionCategory.refund
        : isSeller
            ? TransactionCategory.resaleSale
            : (rawType == 'resale' ? TransactionCategory.resalePurchase : TransactionCategory.ticketPurchase);

    final paid = (row['amount'] as num).toDouble();
    final fee = (row['platform_fee'] as num).toDouble();

    // transactions.amount is what the BUYER paid (the listed price, with no
    // fee added on top). FairTix's fee comes out of the receiving side, so:
    //  - a buyer's receipt shows just what they paid, and no fee;
    //  - a seller's receipt (resale sale) shows what they actually receive,
    //    i.e. the sale price minus FairTix's flat 5% resale fee.
    final amount = category == TransactionCategory.resaleSale ? paid - fee : paid;

    final rawStatus = row['status'] as String;
    final status = switch (rawStatus) {
      'completed' => TransactionStatus.completed,
      'pending' => TransactionStatus.pending,
      'refunded' => TransactionStatus.refunded,
      _ => TransactionStatus.failed,
    };

    return AppTransaction(
      id: row['transaction_id'] as String,
      eventTitle: (row['event_title'] as String?) ?? 'Unknown event',
      tierName: (row['tier_name'] as String?) ?? 'Ticket',
      category: category,
      amount: amount,
      subtotal: paid,
      platformFee: category == TransactionCategory.resaleSale ? fee : null,
      dateTime: DateTime.parse(row['created_at'] as String),
      paymentMethod: 'PayMongo Sandbox',
      status: status,
      ticketId: row['ticket_id'] as String?,
    );
  }
}
