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

enum TransactionCategory { ticketPurchase, resalePurchase, resaleSale }

enum TransactionStatus { completed, pending, failed }

/// Placeholder payment transaction model for UI scaffolding.
/// TODO: replace with the real TRANSACTIONS Firestore document (linked to
/// a PayMongo Sandbox payment intent) once the payment backend is wired up.
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

  /// True for money the user received (a resale sale); false for money paid.
  bool get isCredit => category == TransactionCategory.resaleSale;

  String get categoryLabel => switch (category) {
        TransactionCategory.ticketPurchase => 'Ticket Purchase',
        TransactionCategory.resalePurchase => 'Resale Purchase',
        TransactionCategory.resaleSale => 'Resale Sale',
      };

  IconData get categoryIcon => switch (category) {
        TransactionCategory.ticketPurchase => Icons.confirmation_number_rounded,
        TransactionCategory.resalePurchase => Icons.swap_horiz_rounded,
        TransactionCategory.resaleSale => Icons.sell_rounded,
      };

  String get statusLabel => switch (status) {
        TransactionStatus.completed => 'Completed',
        TransactionStatus.pending => 'Pending',
        TransactionStatus.failed => 'Failed',
      };
}
