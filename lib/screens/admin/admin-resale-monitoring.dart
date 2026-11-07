import 'package:flutter/material.dart';

import '../../services/admin_resale_service.dart';
import '../../services/csv_export.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_ui.dart';

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
  State<AdminResaleMonitoringScreen> createState() =>
      _AdminResaleMonitoringScreenState();
}

class _AdminResaleMonitoringScreenState
    extends State<AdminResaleMonitoringScreen> {
  static const _statusFilters = [
    'All',
    'Active',
    'Sold',
    'Canceled',
    'Expired',
  ];

  /// Relative column widths (seller, event, original, resale, % of original,
  /// status, action).
  static const _flex = [3, 3, 2, 2, 2, 2, 2];

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
      if (_statusFilter != 'All' && l.statusLabel != _statusFilter) {
        return false;
      }
      if (_nearFloorOnly && !l.isNearFloor) return false;
      if (query.isEmpty) return true;
      return '${l.sellerName} ${l.sellerEmail} ${l.eventTitle}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  int _countFor(String filter) => filter == 'All'
      ? _listings.length
      : _listings.where((l) => l.statusLabel == filter).length;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeListing(ResaleListingEntry listing) async {
    final p = FairTixPalette.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminDialog(
        title: 'Remove this listing?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminDialogText(
              '${listing.sellerName}\'s ${listing.tierName} ticket for "${listing.eventTitle}" '
              '(${formatPeso(listing.listingPrice)}) is taken off the market. The ticket '
              'goes back to their wallet as a normal valid ticket and they are notified.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 200,
              style: orgText(p, size: 14, height: 1.3),
              cursorColor: p.accentLabel,
              decoration: adminInputDecoration(
                ctx,
                label: 'Reason (shown to the seller, optional)',
              ),
            ),
          ],
        ),
        actions: [
          AdminDialogButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AdminDialogButton(
            label: 'Remove Listing',
            color: p.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;

    setState(() => _busyListingId = listing.id);
    try {
      await AdminResaleService.instance.removeListing(
        listing.id,
        reason: reason,
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
    final p = FairTixPalette.of(context);
    final active = _listings.where((l) => l.isActive).toList();
    final activeValue = active.fold<double>(
      0,
      (sum, l) => sum + l.listingPrice,
    );
    final avgFraction = active.isEmpty
        ? 0.0
        : active.fold<double>(0, (sum, l) => sum + l.fractionOfOriginal) /
              active.length;
    final nearFloor = active.where((l) => l.isNearFloor).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Resale Monitoring',
          subtitle:
              'Every resale listing, compared with the price the seller originally paid.',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading,
              onPressed: _isLoading ? null : _load,
            ),
            AdminHeaderButton(
              icon: Icons.download_outlined,
              label: 'Export CSV',
              onPressed: _isLoading ? null : _exportCsv,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const FtShimmer(child: AdminSkeletonSummaryRow(count: 4))
        else
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.swap_vert_rounded,
              color: p.accentLabel,
              label: 'Active Listings',
              value: '${active.length}',
              caption: '${_listings.length} listings in total',
            ),
            AdminSummaryCard(
              icon: Icons.payments_outlined,
              color: p.success,
              label: 'Active Listed Value',
              value: formatPeso(activeValue),
              caption: 'Asking prices, before the resale fee',
            ),
            AdminSummaryCard(
              icon: Icons.percent_outlined,
              color: p.accentLabel,
              label: 'Avg Price vs Original',
              value: active.isEmpty
                  ? '\u2014'
                  : '${(avgFraction * 100).round()}%',
              caption: 'Allowed range is 50%\u2013100%',
            ),
            AdminSummaryCard(
              icon: Icons.flag_outlined,
              color: p.danger,
              label: 'Near-Floor Listings',
              value: '$nearFloor',
              caption: 'Active, at or below 60% of original',
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 1000;
            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildListings()),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildActivity()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildListings(),
                const SizedBox(height: 20),
                _buildActivity(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildListings() {
    final p = FairTixPalette.of(context);
    final filtered = _filtered;
    final ready = !_isLoading && _loadError == null;

    final Widget table;
    if (_isLoading) {
      table = LayoutBuilder(
        builder: (context, constraints) => FtShimmer(
          child: AdminSkeletonTableBody(
            flex: _flex,
            compact: constraints.maxWidth < 760,
          ),
        ),
      );
    } else if (_loadError != null) {
      table = AdminErrorBox(message: _loadError!, onRetry: _load);
    } else if (filtered.isEmpty) {
      table = AdminEmptyState(
        icon: Icons.swap_vert_rounded,
        title: _listings.isEmpty
            ? 'No resale listings yet'
            : 'No listings match your filters',
        hint: _listings.isEmpty
            ? 'Listings will appear here when eventgoers put tickets up for resale.'
            : 'Try a different search or status.',
      );
    } else {
      table = LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                const AdminTableHeader(
                  labels: [
                    'Seller',
                    'Event',
                    'Original',
                    'Resale',
                    '% of orig.',
                    'Status',
                    '',
                  ],
                  flex: _flex,
                ),
              for (final listing in filtered)
                _ListingRow(
                  listing: listing,
                  wide: wide,
                  flex: _flex,
                  busy: _busyListingId == listing.id,
                  onRemove: () => _removeListing(listing),
                ),
              Divider(height: 1, color: p.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  'Showing ${filtered.length} of ${_listings.length} listings',
                  style: orgText(p, size: 12, color: p.textSecondary),
                ),
              ),
            ],
          );
        },
      );
    }

    return AdminCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminFilterChips(
                    labels: _statusFilters,
                    selected: _statusFilters.indexOf(_statusFilter),
                    counts: [
                      for (final f in _statusFilters)
                        ready ? _countFor(f) : null,
                    ],
                    onSelected: (i) =>
                        setState(() => _statusFilter = _statusFilters[i]),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AdminSearchField(
                        hint: 'Search seller or event',
                        width: 280,
                        onChanged: (_) => setState(() {}),
                      ),
                      AdminToggleChip(
                        label: 'Near floor only',
                        icon: Icons.flag_outlined,
                        selected: _nearFloorOnly,
                        onChanged: (v) => setState(() => _nearFloorOnly = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: table,
            ),
          ],
        ),
      ),
    );
  }

  /// The latest listing activity (new listings and sales), newest first.
  /// Resale purchases aren't built yet, so for now this is mostly new
  /// listings; "sold" lines appear once that flow exists.
  Widget _buildActivity() {
    final p = FairTixPalette.of(context);
    final events = <({DateTime at, String text})>[];
    for (final l in _listings) {
      events.add((
        at: l.listedAt,
        text:
            '${l.sellerName} listed ${l.tierName} \u2013 ${l.eventTitle} at ${formatPeso(l.listingPrice)}',
      ));
      final soldAt = l.soldAt;
      if (soldAt != null) {
        events.add((
          at: soldAt,
          text:
              '${l.tierName} \u2013 ${l.eventTitle} sold for ${formatPeso(l.listingPrice)}',
        ));
      }
    }
    events.sort((a, b) => b.at.compareTo(a.at));
    final latest = events.take(8).toList();

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recent Listing Activity',
            style: orgText(p, size: 16, weight: FontWeight.w700),
          ),
          Divider(height: 24, color: p.border),
          if (_isLoading)
            const FtShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SkeletonActivityItem(),
                  _SkeletonActivityItem(),
                  _SkeletonActivityItem(),
                  _SkeletonActivityItem(),
                ],
              ),
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
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.text, style: orgText(p, size: 13, height: 1.35)),
                    const SizedBox(height: 2),
                    Text(
                      formatAdminDateTime(item.at),
                      style: orgText(p, size: 12, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Placeholder for one line of the Recent Listing Activity card.
class _SkeletonActivityItem extends StatelessWidget {
  const _SkeletonActivityItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FtSkeletonBox(height: 13),
          SizedBox(height: 6),
          FtSkeletonBox(width: 120, height: 12),
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
    required this.flex,
    required this.busy,
    required this.onRemove,
  });

  final ResaleListingEntry listing;
  final bool wide;
  final List<int> flex;
  final bool busy;
  final VoidCallback onRemove;

  Widget _percent(BuildContext context) {
    final p = FairTixPalette.of(context);
    final pct = '${(listing.fractionOfOriginal * 100).round()}%';
    final color = listing.isNearFloor ? p.danger : p.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pct,
          style: orgText(p, size: 13, weight: FontWeight.w700, color: color),
        ),
        if (listing.isNearFloor) ...[
          const SizedBox(width: 5),
          Tooltip(
            message: 'Near the 50% floor',
            child: Icon(Icons.flag, size: 14, color: p.danger),
          ),
        ],
      ],
    );
  }

  Widget _removeButton(BuildContext context) => listing.isActive
      ? AdminRowAction(
          label: busy ? 'Working...' : 'Remove',
          color: FairTixPalette.of(context).danger,
          onPressed: busy ? null : onRemove,
        )
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    if (wide) {
      return AdminTableRow(
        children: [
          Expanded(
            flex: flex[0],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.sellerName,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    listing.sellerEmail,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 12,
                      color: p.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: flex[1],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.eventTitle,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(p, size: 13, height: 1.3),
                  ),
                  Text(
                    listing.tierName,
                    overflow: TextOverflow.ellipsis,
                    style: orgText(
                      p,
                      size: 12,
                      color: p.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          adminCell(context, flex[2], formatPeso(listing.originalPrice)),
          adminCell(
            context,
            flex[3],
            formatPeso(listing.listingPrice),
            bold: true,
          ),
          Expanded(
            flex: flex[4],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _percent(context),
            ),
          ),
          Expanded(
            flex: flex[5],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _listingStatusBadge(listing),
            ),
          ),
          Expanded(
            flex: flex[6],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _removeButton(context),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.sellerName,
                  style: orgText(p, size: 15, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _listingStatusBadge(listing),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${listing.eventTitle} \u2022 ${listing.tierName}',
            style: orgText(p, size: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${formatPeso(listing.listingPrice)} of ${formatPeso(listing.originalPrice)}  ',
                style: orgText(p, size: 13, color: p.textSecondary),
              ),
              _percent(context),
            ],
          ),
          if (listing.isActive) ...[
            const SizedBox(height: 12),
            _removeButton(context),
          ],
        ],
      ),
    );
  }
}
