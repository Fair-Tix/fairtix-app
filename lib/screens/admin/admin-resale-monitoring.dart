import 'package:flutter/material.dart';

import '../../services/admin_resale_service.dart';
import '../../services/csv_export.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../organizer/app_colors.dart';

/// Every resale listing on the platform, with the price compared to what the
/// seller originally paid, and the admin's one action: take a listing off
/// the market.
///
/// There is no "markup" column on purpose. The server forces every listing
/// into 50%-100% of the original price (`list_ticket_for_resale`,
/// supabase/resale_functions.sql), so what is worth watching is how far
/// *below* face value a listing is. Listings at or under 60% are marked
/// "Near floor" and also get an automatic price flag on the Fraud Alerts
/// screen (supabase/fraud_alerts.sql).
class AdminResaleMonitoringScreen extends StatefulWidget {
  const AdminResaleMonitoringScreen({super.key});

  @override
  State<AdminResaleMonitoringScreen> createState() => _AdminResaleMonitoringScreenState();
}

class _AdminResaleMonitoringScreenState extends State<AdminResaleMonitoringScreen> {
  static const _statusFilters = ['All', 'Active', 'Sold', 'Canceled', 'Expired'];

  final _searchController = TextEditingController();
  List<ResaleListingEntry> _listings = const [];
  bool _isLoading = true;
  String? _loadError;
  String _statusFilter = 'All';
  bool _nearFloorOnly = false;
  String? _busyListingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final listings = await AdminResaleService.instance.fetchListings();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _isLoading = false;
        _loadError = null;
      });
    } on AdminResaleException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<ResaleListingEntry> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _listings.where((l) {
      if (_statusFilter != 'All' && l.statusLabel != _statusFilter) return false;
      if (_nearFloorOnly && !l.isNearFloor) return false;
      if (query.isEmpty) return true;
      return '${l.sellerName} ${l.sellerEmail} ${l.eventTitle}'.toLowerCase().contains(query);
    }).toList();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeListing(ResaleListingEntry listing) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${listing.sellerName}\'s ${listing.tierName} ticket for "${listing.eventTitle}" '
              '(${formatPeso(listing.listingPrice)}) is taken off the market. The ticket '
              'goes back to their wallet as a normal valid ticket and they are notified.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reason (shown to the seller, optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            child: const Text('Remove Listing'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyListingId = listing.id);
    try {
      await AdminResaleService.instance.removeListing(
        listing.id,
        reason: reasonController.text.trim(),
      );
      await _load(showSpinner: false);
      _toast('Listing removed and the seller was notified.');
    } on AdminResaleException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyListingId = null);
    }
  }

  Future<void> _exportCsv() async {
    final rows = _filtered;
    if (rows.isEmpty) {
      _toast('There are no resale listings to export.');
      return;
    }
    final csv = resaleListingsToCsv(rows);
    final saved = await saveCsvFile(
      fileName: 'fairtix-resale-${formatIsoDate(DateTime.now())}.csv',
      csv: csv,
    );
    _toast(saved ? 'Resale listings exported.' : 'Export canceled.');
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.resaleMonitoring,
      title: 'Resale Monitoring',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final active = _listings.where((l) => l.isActive).toList();
    final activeValue = active.fold<double>(0, (sum, l) => sum + l.listingPrice);
    final avgFraction = active.isEmpty
        ? 0.0
        : active.fold<double>(0, (sum, l) => sum + l.fractionOfOriginal) / active.length;
    final nearFloor = active.where((l) => l.isNearFloor).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Resale Monitoring', style: AppTextStyles.h2)),
            IconButton(
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _exportCsv,
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.swap_vert_rounded,
              color: AppColors.primaryPurple,
              label: 'Active Listings',
              value: '${active.length}',
              caption: '${_listings.length} listings in total',
            ),
            AdminSummaryCard(
              icon: Icons.payments_outlined,
              color: AppColors.successGreen,
              label: 'Active Listed Value',
              value: formatPeso(activeValue),
              caption: 'Asking prices, before the resale fee',
            ),
            AdminSummaryCard(
              icon: Icons.percent_outlined,
              color: AppColors.infoBlue,
              label: 'Avg Price vs Original',
              value: active.isEmpty ? '\u2014' : '${(avgFraction * 100).round()}%',
              caption: 'Allowed range is 50%\u2013100%',
            ),
            AdminSummaryCard(
              icon: Icons.flag_outlined,
              color: AppColors.dangerRed,
              label: 'Near-Floor Listings',
              value: '$nearFloor',
              caption: 'Active, at or below 60% of original',
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 1000;
            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildListings()),
                  const SizedBox(width: 18),
                  Expanded(flex: 3, child: _buildActivity()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_buildListings(), const SizedBox(height: 18), _buildActivity()],
            );
          },
        ),
      ],
    );
  }

  Widget _buildListings() {
    final filtered = _filtered;
    return AdminCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search seller or event...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Icons.search, size: 17, color: AppColors.textGray),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8F7FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final f in _statusFilters)
                      DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value ?? 'All'),
                ),
                FilterChip(
                  label: const Text('Near floor only', style: TextStyle(fontSize: 11)),
                  selected: _nearFloorOnly,
                  onSelected: (value) => setState(() => _nearFloorOnly = value),
                  selectedColor: AppColors.dangerRedBg,
                  checkmarkColor: AppColors.dangerRed,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (_loadError != null)
            AdminErrorBox(message: _loadError!, onRetry: _load)
          else if (filtered.isEmpty)
            AdminEmptyState(
              icon: Icons.swap_vert_rounded,
              title: _listings.isEmpty ? 'No resale listings yet' : 'No listings match your filters',
              hint: _listings.isEmpty
                  ? 'Listings will appear here when eventgoers put tickets up for resale.'
                  : 'Try a different search or status.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 640;
                return Column(
                  children: [
                    if (wide)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text('SELLER', style: adminHeaderStyle)),
                            Expanded(flex: 3, child: Text('EVENT', style: adminHeaderStyle)),
                            Expanded(flex: 2, child: Text('ORIGINAL', style: adminHeaderStyle)),
                            Expanded(flex: 2, child: Text('RESALE', style: adminHeaderStyle)),
                            Expanded(flex: 2, child: Text('% OF ORIG.', style: adminHeaderStyle)),
                            Expanded(flex: 2, child: Text('STATUS', style: adminHeaderStyle)),
                            SizedBox(width: 70),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    for (final listing in filtered)
                      _ListingRow(
                        listing: listing,
                        wide: wide,
                        busy: _busyListingId == listing.id,
                        onRemove: () => _removeListing(listing),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Showing ${filtered.length} of ${_listings.length} listings',
                          style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// The latest listing activity (new listings and sales), newest first.
  /// Resale purchases aren't built yet, so for now this is mostly new
  /// listings; "sold" lines appear once that flow exists.
  Widget _buildActivity() {
    final events = <({DateTime at, String text})>[];
    for (final l in _listings) {
      events.add((
        at: l.listedAt,
        text: '${l.sellerName} listed ${l.tierName} \u2013 ${l.eventTitle} at ${formatPeso(l.listingPrice)}',
      ));
      final soldAt = l.soldAt;
      if (soldAt != null) {
        events.add((
          at: soldAt,
          text: '${l.tierName} \u2013 ${l.eventTitle} sold for ${formatPeso(l.listingPrice)}',
        ));
      }
    }
    events.sort((a, b) => b.at.compareTo(a.at));
    final latest = events.take(8).toList();

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Recent Listing Activity', style: AppTextStyles.h3),
          const Divider(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (latest.isEmpty)
            const AdminEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No activity yet',
              hint: 'New listings and sales will show up here.',
            )
          else
            for (final item in latest)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.text, style: const TextStyle(fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(
                      formatAdminDateTime(item.at),
                      style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

AdminBadge _listingStatusBadge(ResaleListingEntry l) => switch (l.status) {
  'active' => AdminBadge.success(l.statusLabel),
  'sold' => AdminBadge.info(l.statusLabel),
  'expired' => AdminBadge.warning(l.statusLabel),
  _ => AdminBadge.neutral(l.statusLabel),
};

class _ListingRow extends StatelessWidget {
  const _ListingRow({
    required this.listing,
    required this.wide,
    required this.busy,
    required this.onRemove,
  });

  final ResaleListingEntry listing;
  final bool wide;
  final bool busy;
  final VoidCallback onRemove;

  Widget _percent() {
    final pct = '${(listing.fractionOfOriginal * 100).round()}%';
    final color = listing.isNearFloor ? AppColors.dangerRed : AppColors.textDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(pct, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        if (listing.isNearFloor) ...[
          const SizedBox(width: 4),
          const Tooltip(
            message: 'Near the 50% floor',
            child: Icon(Icons.flag, size: 13, color: AppColors.dangerRed),
          ),
        ],
      ],
    );
  }

  Widget _removeButton() => listing.isActive
      ? TextButton(
          onPressed: busy ? null : onRemove,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.dangerRed,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
          ),
          child: Text(busy ? 'Working...' : 'Remove', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        )
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final content = wide
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.sellerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(listing.sellerEmail, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.eventTitle, style: const TextStyle(fontSize: 11.5)),
                      Text(listing.tierName, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text(formatPeso(listing.originalPrice), style: const TextStyle(fontSize: 11))),
                Expanded(flex: 2, child: Text(formatPeso(listing.listingPrice), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _percent())),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _listingStatusBadge(listing))),
                SizedBox(width: 70, child: _removeButton()),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(listing.sellerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    _listingStatusBadge(listing),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${listing.eventTitle} \u2022 ${listing.tierName}', style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${formatPeso(listing.listingPrice)} of ${formatPeso(listing.originalPrice)}  ', style: const TextStyle(fontSize: 11)),
                    _percent(),
                  ],
                ),
                _removeButton(),
              ],
            ),
          );
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
      child: content,
    );
  }
}
