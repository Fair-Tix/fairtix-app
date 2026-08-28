import '../models/transaction.dart';

/// Transaction history (ticket purchases, resale purchases, resale
/// sales) for the current user.
/// TODO(backend): replace with a real query against the TRANSACTIONS
/// Firestore collection filtered by user_id once the backend is wired
/// up.
///
/// Starts empty on every app run — no sample/dummy transactions are
/// seeded here. Screens that read this already render an empty state
/// when the list has no entries.
final List<AppTransaction> sampleTransactions = [];
