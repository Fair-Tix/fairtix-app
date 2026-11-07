import 'package:flutter/material.dart';

import '../../models/event.dart' show EventSummary;
import '../../services/public_event_repository.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/ft_skeleton.dart';
import '../../widgets/organizer_ui.dart';
import '../user/event_details_screen.dart';

/// View-only list of the published catalogue event goers see, opened from
/// Events & Tickets > "Browse Published Events". Reads the same
/// [PublicEventRepository] as the eventgoer "All Events" screen and opens
/// each event in read-only mode (no ticket selection or purchase).
class AdminBrowseEventsScreen extends StatefulWidget {
  const AdminBrowseEventsScreen({super.key});

  @override
  State<AdminBrowseEventsScreen> createState() =>
      _AdminBrowseEventsScreenState();
}

class _AdminBrowseEventsScreenState extends State<AdminBrowseEventsScreen> {
  /// Relative column widths (event, date, venue, from price, action).
  static const _flex = [5, 3, 4, 2, 2];

  String _search = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await PublicEventRepository.instance.refresh();
    } on PublicEventRepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EventSummary> get _filtered {
    final all = PublicEventRepository.instance.events;
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.venue.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Cheapest tier: "TBA" with no tiers, "Free", otherwise the peso amount
  /// without ".00".
  static String _price(EventSummary event) {
    if (event.tiers.isEmpty) return 'TBA';
    final lowest = event.tiers
        .map((t) => t.price)
        .reduce((a, b) => a < b ? a : b);
    if (lowest <= 0) return 'Free';
    final label = formatPeso(lowest);
    return label.endsWith('.00') ? label.substring(0, label.length - 3) : label;
  }

  void _open(EventSummary event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailsScreen(event: event, readOnly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.eventsTickets,
      title: 'Browse Published Events',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = FairTixPalette.of(context);
    final all = PublicEventRepository.instance.events;
    final filtered = _filtered;

    final Widget content;
    if (_isLoading && all.isEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) => FtShimmer(
          child: AdminSkeletonTableBody(
            flex: _flex,
            compact: constraints.maxWidth < 760,
          ),
        ),
      );
    } else if (_error != null && all.isEmpty) {
      content = AdminErrorBox(message: _error!, onRetry: _load);
    } else if (filtered.isEmpty) {
      content = AdminEmptyState(
        icon: Icons.event_busy_outlined,
        title: all.isEmpty
            ? 'No published events yet'
            : 'No events match your search',
        hint: all.isEmpty
            ? 'Events appear here once organizers publish them.'
            : 'Try a different search.',
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                const AdminTableHeader(
                  labels: ['Event', 'Date', 'Venue', 'From', ''],
                  flex: _flex,
                ),
              for (final event in filtered)
                wide ? _wideRow(event) : _compactRow(event),
              Divider(height: 1, color: p.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  'Showing ${filtered.length} of ${all.length} events',
                  style: orgText(p, size: 12, color: p.textSecondary),
                ),
              ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Browse Published Events',
          subtitle:
              'The published catalogue event goers see. View only: no ticket selection or purchase.',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading,
              onPressed: _isLoading ? null : _load,
            ),
            AdminHeaderButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back to Events & Tickets',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminSearchField(
            hint: 'Search event or venue',
            width: 320,
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  Widget _wideRow(EventSummary event) {
    return AdminTableRow(
      children: [
        adminCell(context, _flex[0], event.title, bold: true),
        adminCell(context, _flex[1], event.dateLabel),
        adminCell(context, _flex[2], event.venue, muted: true),
        adminCell(context, _flex[3], _price(event), bold: true),
        Expanded(
          flex: _flex[4],
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminRowAction(label: 'View', onPressed: () => _open(event)),
          ),
        ),
      ],
    );
  }

  Widget _compactRow(EventSummary event) {
    final p = FairTixPalette.of(context);
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
                  event.title,
                  style: orgText(p, size: 15, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _price(event),
                style: orgText(
                  p,
                  size: 14,
                  weight: FontWeight.w700,
                  color: p.accentLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${event.dateLabel} \u2022 ${event.venue}',
            style: orgText(p, size: 13, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          AdminRowAction(label: 'View', onPressed: () => _open(event)),
        ],
      ),
    );
  }
}
