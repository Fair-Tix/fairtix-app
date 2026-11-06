import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/transaction.dart';
import '../../services/transaction_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_subpage_ui.dart';
import '../../widgets/ft_transaction_ui.dart';
import 'transaction_detail_screen.dart';

/// Which transactions the list shows.
enum _Filter {
  all('All'),
  purchases('Purchases'),
  sales('Sales'),
  refunds('Refunds');

  const _Filter(this.label);

  final String label;

  bool matches(TransactionCategory category) => switch (this) {
        _Filter.all => true,
        _Filter.purchases =>
          category == TransactionCategory.ticketPurchase ||
              category == TransactionCategory.resalePurchase,
        _Filter.sales => category == TransactionCategory.resaleSale,
        _Filter.refunds => category == TransactionCategory.refund,
      };
}

/// "Transactions" screen — every payment the current user has made or
/// received (ticket purchases, resale purchases, resale sales, refunds),
/// newest first, backed by [TransactionRepository] (the
/// `get_my_transactions()` Supabase function). Reached from the Profile
/// tab, or directly from a "your ticket has been bought" notification.
///
/// Dark design: round back button, All / Purchases / Sales / Refunds chips,
/// and one grouped card with an amount and status badge per row.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  /// [showSpinner] is false for pull-to-refresh, which has its own spinner.
  Future<void> _loadTransactions({bool showSpinner = true}) async {
    setState(() {
      _isLoading = showSpinner;
      _errorMessage = null;
    });
    try {
      await TransactionRepository.instance.refresh();
    } on TransactionRepositoryException catch (e) {
      _errorMessage = e.message;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openTransaction(AppTransaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: transaction)),
    );
  }

  List<Widget> _content(
    FtAuthTheme t,
    List<AppTransaction> visible,
    bool noTransactionsAtAll,
  ) {
    if (_isLoading) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator(color: t.activeAccent)),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center, style: t.subtitle()),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadTransactions,
                child: Text('Try again', style: t.link()),
              ),
            ],
          ),
        ),
      ];
    }

    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, size: 48, color: t.activeAccent.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text(
                noTransactionsAtAll ? 'No transactions yet' : 'No ${_filter.label.toLowerCase()} yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: t.titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                noTransactionsAtAll
                    ? 'Purchases, resales and refunds will show up here.'
                    : 'Nothing to show for this filter.',
                textAlign: TextAlign.center,
                style: t.subtitle(),
              ),
            ],
          ),
        ),
      ];
    }

    final count = visible.length;
    return [
      Container(
        decoration: BoxDecoration(
          color: t.surfaceFill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        // The Material sits above the card's fill so the tap ripple shows.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 22, endIndent: 22, color: t.divider),
                _TransactionRow(
                  transaction: visible[i],
                  onTap: () => _openTransaction(visible[i]),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Text(
          'Showing your $count most recent transaction${count == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: t.subtitle(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final all = TransactionRepository.instance.transactions;
    final visible = all.where((tx) => _filter.matches(tx.category)).toList();

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: t.overlayStyle,
        child: Scaffold(
          backgroundColor: t.bgBottom,
          body: FtAuthBackground(
            theme: t,
            child: SafeArea(
              child: RefreshIndicator(
                color: t.activeAccent,
                backgroundColor: t.surfaceFill,
                onRefresh: () => _loadTransactions(showSpinner: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                  children: [
                    FtPageHeader(
                      title: 'Transactions',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 22),
                    _FilterChips(
                      selected: _filter,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 22),
                    ..._content(t, visible, all.isEmpty),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The All / Purchases / Sales / Refunds pills. The selected one is filled
/// with the brand purple gradient.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    // Scales the row down only when the screen is too narrow, so all four
    // chips stay visible instead of the last one being cut off.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final filter in _Filter.values) ...[
            if (filter != _Filter.all) const SizedBox(width: 8),
            _chip(t, filter),
          ],
        ],
      ),
    );
  }

  Widget _chip(FtAuthTheme t, _Filter filter) {
    final isSelected = filter == selected;
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      selected: isSelected,
      label: filter.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: isSelected ? FairTixPalette.buttonGradient : null,
          color: isSelected ? null : t.surfaceFill,
          border: isSelected ? null : Border.all(color: t.surfaceBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => onSelected(filter),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: Text(
                filter.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? Colors.white : t.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line in the grouped card: what it was and when on the left, the amount
/// and its status badge on the right.
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.onTap});

  final AppTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final prefix = transaction.isCredit ? '+' : '−';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w800,
                      color: t.titleColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${transaction.eventTitle} · ${formatShortDate(transaction.dateTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: t.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${formatPesoShort(transaction.amount)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: t.titleColor,
                  ),
                ),
                const SizedBox(height: 7),
                FtTransactionStatusPill(status: transaction.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
