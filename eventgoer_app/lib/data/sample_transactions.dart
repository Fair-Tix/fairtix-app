import '../models/transaction.dart';

/// Placeholder transaction history for UI scaffolding.
/// TODO: replace with a real query against the TRANSACTIONS Firestore
/// collection filtered by user_id once the backend is wired up.
final List<AppTransaction> sampleTransactions = [
  AppTransaction(
    id: 'txn_0001',
    eventTitle: 'A1 – Love in the Philippines Tour 2026',
    tierName: 'VIP',
    category: TransactionCategory.ticketPurchase,
    subtotal: 5000,
    platformFee: 500,
    amount: 5500,
    dateTime: DateTime(2026, 6, 20, 10, 15),
    paymentMethod: 'GCash (Simulated)',
  ),
  AppTransaction(
    id: 'txn_0002',
    eventTitle: 'A1 – Love in the Philippines Tour 2026',
    tierName: 'General Access',
    category: TransactionCategory.ticketPurchase,
    subtotal: 1000,
    platformFee: 100,
    amount: 1100,
    dateTime: DateTime(2026, 6, 21, 14, 32),
    paymentMethod: 'Maya (Simulated)',
  ),
  AppTransaction(
    id: 'txn_0003',
    eventTitle: 'BINI Signals World Tour',
    tierName: 'General Admission',
    category: TransactionCategory.ticketPurchase,
    subtotal: 1399,
    platformFee: 139.9,
    amount: 1538.9,
    dateTime: DateTime(2026, 6, 22, 9, 5),
    paymentMethod: 'Card •••• 4521',
  ),
  AppTransaction(
    id: 'txn_0004',
    eventTitle: 'A1 – Love in the Philippines Tour 2026',
    tierName: 'VIP',
    category: TransactionCategory.resaleSale,
    amount: 5000,
    dateTime: DateTime(2026, 6, 27, 9, 41),
    paymentMethod: 'Escrow Release',
    ticketId: 'tkt_0001',
  ),
];
