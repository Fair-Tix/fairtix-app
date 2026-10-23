import 'package:flutter/material.dart';

import '../../data/sample_tickets.dart';
import '../../models/ticket.dart';
import '../../navigation/tab_index_notifier.dart';
import '../../services/access_control.dart';
import '../../services/resale_repository.dart';
import '../../services/ticket_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/market_listing_card.dart';
import '../../widgets/my_listing_card.dart';
import '../../widgets/resale_filter_chip.dart';
import 'resale_checkout_screen.dart';
import 'ticket_detail_screen.dart';

/// "Resale Market" tab — browse other users' active resale listings, and
/// see the current user's own listed tickets at the top.
class ResaleMarketScreen extends StatefulWidget {
  const ResaleMarketScreen({super.key});

  @override
  State<ResaleMarketScreen> createState() => _ResaleMarketScreenState();
}

class _ResaleMarketScreenState extends State<ResaleMarketScreen> {
  static const _categories = ['All', 'Concerts', 'Sports', 'Theater'];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  /// Other users' active listings, from the `get_resale_market()` database
  /// function. Empty until the first load finishes.
  List<Ticket> _market = [];
  bool _marketLoading = true;
  String? _marketError;

  @override
  void initState() {
    super.initState();
    _refresh();
    mainShellTabIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    mainShellTabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  // This tab stays alive inside the shell's PageView, so initState only
  // runs once. Reload whenever the user switches back to it (e.g. via
  // "View Listing" after listing a ticket) so new listings show up.
  void _onTabChanged() {
    if (mainShellTabIndex.value == 2) _refresh();
  }

  /// Reloads the user's own wallet (for "My Listed Tickets" and the purchase
  /// limit check) and the market. Each part fails on its own: a market error
  /// is shown in the market section, and a wallet error leaves what's there.
  Future<void> _refresh() async {
    await Future.wait([_refreshMyListings(), _refreshMarket()]);
  }

  Future<void> _refreshMyListings() async {
    try {
      await TicketRepository.instance.refresh();
      if (mounted) setState(() {});
    } on TicketRepositoryException {
      // Keep showing what we already have.
    }
  }

  Future<void> _refreshMarket() async {
    if (mounted) setState(() => _marketError = null);
    try {
      final market = await ResaleRepository.instance.fetchMarket();
      if (!mounted) return;
      setState(() => _market = market);
    } on ResaleException catch (e) {
      if (!mounted) return;
      setState(() => _marketError = e.message);
    } finally {
      if (mounted) setState(() => _marketLoading = false);
    }
  }

  // Category chips are currently cosmetic only — events don't carry a
  // category field yet.
  //
  // Listings whose event has passed the 24-hour resale-closing window are
  // excluded here as well as on the server, mirroring the study's rule that
  // active listings automatically close 24 hours before the event and any
  // unsold ticket is returned to its owner.
  List<Ticket> get _myListings => TicketRepository.instance.tickets
      .where((t) => t.status == TicketStatus.listed && !t.event.isResaleWindowClosed)
      .toList();

  List<Ticket> get _marketListings {
    final active = _market.where((t) => !t.event.isResaleWindowClosed);
    if (_searchQuery.isEmpty) return active.toList();
    final query = _searchQuery.toLowerCase();
    return active.where((t) => t.event.title.toLowerCase().contains(query)).toList();
  }

  void _openMyTicket(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
    );
  }

  Future<void> _buyListing(Ticket listing) async {
    if (isPurchaseLimitReached(listing.event.id)) return;
    // Buying needs an admin-approved account; browsing the market stays open.
    if (!await ensureBuyerApproved(context)) return;
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ResaleCheckoutScreen(listing: listing)))
        // Back from checkout: the listing is gone if it was bought, and the
        // new ticket changes the purchase-limit state of the cards.
        .then((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final myListings = _myListings;
    final marketListings = _marketListings;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Resale Market', style: AppTextStyles.sectionHeading),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.accentPurple, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Buy and sell tickets safely', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inputFillLight,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.inputBorderLight),
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: AppColors.accentPurple, size: 20),
                          hintText: 'Search resale tickets...',
                          hintStyle: AppTextStyles.bodyMuted,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return ResaleFilterChip(
                            label: category,
                            isSelected: category == _selectedCategory,
                            onTap: () => setState(() => _selectedCategory = category),
                          );
                        },
                      ),
                    ),
                    if (myListings.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'MY LISTED TICKETS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accentPurple, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 10),
                      ...myListings.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MyListingCard(ticket: t, onTap: () => _openMyTicket(t)),
                          )),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'MARKET LISTINGS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accentPurple, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 10),
                    if (_marketLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator(color: AppColors.accentPurple)),
                      )
                    else if (_marketError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Text(_marketError!, textAlign: TextAlign.center, style: AppTextStyles.bodyMuted),
                              const SizedBox(height: 10),
                              TextButton(onPressed: _refreshMarket, child: const Text('Try again')),
                            ],
                          ),
                        ),
                      )
                    else if (marketListings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No tickets are listed for resale right now.'
                                : 'No resale tickets match your search.',
                            style: AppTextStyles.bodyMuted,
                          ),
                        ),
                      )
                    else
                      ...marketListings.map((listing) => MarketListingCard(
                            listing: listing,
                            isBlocked: isPurchaseLimitReached(listing.event.id),
                            onBuyNow: () => _buyListing(listing),
                          )),
                  ],
          ),
        ),
        ),
      ),
    );
  }
}
