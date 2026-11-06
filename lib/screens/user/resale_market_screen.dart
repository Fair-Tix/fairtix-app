import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/sample_tickets.dart';
import '../../models/ticket.dart';
import '../../navigation/tab_index_notifier.dart';
import '../../services/access_control.dart';
import '../../services/resale_repository.dart';
import '../../services/ticket_repository.dart';
import '../../services/user_auth_service.dart';
import '../../services/user_session.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_dashboard_ui.dart' show FtProfileAvatar;
import '../../widgets/ft_resale_ui.dart';
import '../../widgets/market_listing_card.dart';
import '../../widgets/my_listing_card.dart';
import '../../widgets/resale_filter_chip.dart';
import 'resale_checkout_screen.dart';
import 'ticket_detail_screen.dart';

/// "Resale Market" tab — browse other users' active resale listings, and
/// see the current user's own listed tickets at the top. Follows the
/// Light / Dark switch.
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

  /// Takes one of the user's own listings off the market after a
  /// confirmation. The ticket goes back to `valid` (see
  /// `cancel_resale_listing` in supabase/resale_functions.sql).
  Future<void> _cancelListing(Ticket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this listing?'),
        content: const Text('Your ticket goes back to My Tickets and is no longer for sale.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep listing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ResaleRepository.instance.cancelListing(ticketId: ticket.id);
    } on ResaleException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing canceled.')));
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

  Widget _marketSection(FtAuthTheme t, List<Ticket> marketListings) {
    if (_marketLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: t.activeAccent)),
      );
    }

    if (_marketError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Text(_marketError!, textAlign: TextAlign.center, style: t.subtitle()),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _refreshMarket,
                child: Text('Try again', style: t.link()),
              ),
            ],
          ),
        ),
      );
    }

    if (marketListings.isEmpty) {
      final searching = _searchQuery.isNotEmpty;
      return FtSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: t.uploadFill,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.swap_horiz_rounded,
                size: 34,
                color: t.activeAccent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              searching ? 'No matches' : 'No listings right now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: t.titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'No resale tickets match your search.'
                  : 'No tickets are listed for resale right now. Listings close 24 hours before an event and never exceed face value.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                height: 1.45,
                color: t.subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final listing in marketListings)
          MarketListingCard(
            listing: listing,
            isBlocked: isPurchaseLimitReached(listing.event.id),
            onBuyNow: () => _buyListing(listing),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.live(context);
    final myListings = _myListings;
    final marketListings = _marketListings;

    final account = UserSession.instance.account;
    final firstName = (account?.fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final initial = firstName.isEmpty ? 'E' : firstName.substring(0, 1).toUpperCase();
    final photoPath = account?.profilePhotoUrl;
    final photoUrl =
        photoPath == null ? null : UserAuthService.instance.profilePhotoPublicUrl(photoPath);

    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: t.overlayStyle,
        child: Scaffold(
          backgroundColor: t.bgBottom,
          body: FtAuthBackground(
            theme: t,
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: t.activeAccent,
                backgroundColor: t.surfaceFill,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Resale Market',
                                  style: FtText.title().copyWith(
                                    fontSize: 33,
                                    letterSpacing: -0.6,
                                    color: t.titleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Buy and sell tickets safely',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  height: 1.3,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Decorative for now: there are no extra filters yet.
                        ExcludeSemantics(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: t.circleFill,
                              shape: BoxShape.circle,
                              border: Border.all(color: t.circleBorder),
                            ),
                            child: Icon(Icons.tune_rounded, color: t.accent, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FtProfileAvatar(
                          initial: initial,
                          photoUrl: photoUrl,
                          onTap: () => mainShellTabIndex.value = 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      height: 62,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: t.fieldFill,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: t.fieldBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: t.iconColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              onChanged: (value) => setState(() => _searchQuery = value.trim()),
                              style: t.input().copyWith(fontSize: 17),
                              cursorColor: t.accent,
                              decoration: InputDecoration(
                                hintText: 'Search resale tickets...',
                                hintStyle: t.hint().copyWith(fontSize: 17),
                                // The app's global input theme draws its own box;
                                // clear every state so only the pill shows.
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                      const SizedBox(height: 26),
                      const FtSectionLabel('My listed tickets'),
                      const SizedBox(height: 14),
                      for (final ticket in myListings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: MyListingCard(
                            ticket: ticket,
                            onTap: () => _openMyTicket(ticket),
                            onCancel: () => _cancelListing(ticket),
                          ),
                        ),
                    ],
                    const SizedBox(height: 14),
                    const FtSectionLabel('Market listings'),
                    const SizedBox(height: 14),
                    _marketSection(t, marketListings),
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
