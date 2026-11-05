import 'package:flutter/material.dart';

import '../../services/admin_event_service.dart';
import '../../services/csv_export.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_document_viewer.dart'
    show AdminReviewDocument, showAdminReviewDialog;
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';
import 'admin-browse-events.dart';

/// Every organizer's events with real sales numbers, plus the admin's two
/// powers from the manuscript: cancel or unpublish any event.
///
/// Reads `public.events` / `ticket_tiers` through [AdminEventService].
/// Canceling here is the same database update the organizer's own Cancel
/// Event button makes, so the `create_refunds_on_event_cancel` trigger
/// (supabase/refund_functions.sql) creates a pending refund per purchase,
/// cancels the tickets and notifies each buyer.
class AdminEventsTicketsScreen extends StatefulWidget {
  const AdminEventsTicketsScreen({super.key});

  @override
  State<AdminEventsTicketsScreen> createState() =>
      _AdminEventsTicketsScreenState();
}

class _AdminEventsTicketsScreenState extends State<AdminEventsTicketsScreen> {
  static const _statusFilters = [
    'All',
    'Published',
    'Unpublished',
    'Draft',
    'Cancelled',
    'Completed',
  ];

  /// Relative column widths (event, organizer, date, sold, status, actions).
  static const _flex = [4, 3, 3, 2, 2, 6];

  final _searchController = TextEditingController();
  List<AdminEventSummary> _events = const [];
  bool _isLoading = true;
  String? _loadError;
  String _statusFilter = 'All';
  final Set<String> _expanded = {};
  String? _busyEventId;

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
      final events = await AdminEventService.instance.fetchEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
        _loadError = null;
      });
    } on AdminEventServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<AdminEventSummary> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _events.where((e) {
      if (_statusFilter != 'All' && e.statusLabel != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return '${e.title} ${e.organizerName} ${e.venue}'.toLowerCase().contains(
        query,
      );
    }).toList();
  }

  int _countFor(String filter) => filter == 'All'
      ? _events.length
      : _events.where((e) => e.statusLabel == filter).length;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelEvent(AdminEventSummary event) async {
    final p = FairTixPalette.of(context);
    final sold = event.ticketsSold;
    final body = sold == 0
        ? 'No tickets have been sold for "${event.title}". It will be marked as cancelled.'
        : 'This cancels "${event.title}" and all $sold ticket${sold == 1 ? '' : 's'} sold '
              '(${formatPeso(event.grossRevenue)}). A refund is created for each purchase, '
              'any resale listings are closed, and every ticket holder is notified. '
              'This cannot be undone.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminDialog(
        title: 'Cancel this event?',
        content: AdminDialogText(body),
        actions: [
          AdminDialogButton(
            label: 'Keep Event',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AdminDialogButton(
            label: 'Cancel Event',
            color: p.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _changeStatus(
      event,
      () => AdminEventService.instance.cancelEvent(event.id),
      sold == 0
          ? 'Event cancelled.'
          : 'Event cancelled. Refunds were created for the ticket holders (see Revenue & Reports).',
    );
  }

  Future<void> _viewDocuments(AdminEventSummary event) {
    return showAdminReviewDialog(
      context: context,
      title: 'Supporting documents',
      subtitle: '${event.title} \u2022 ${event.organizerName}',
      documents: [
        for (final path in event.documentPaths)
          AdminReviewDocument(
            label: path.split('/').last.replaceFirst(RegExp(r'^\d+_'), ''),
            bucket: 'event_documents',
            path: path,
          ),
      ],
      // Anything other than 'pending' shows a plain Close button.
      currentStatus: event.status,
    );
  }

  Future<void> _unpublishEvent(AdminEventSummary event) async {
    final reasonController = TextEditingController();
    var deadlineDays = 7;
    var showReasonError = false;
    final sold = event.ticketsSold;
    final refundNote = sold == 0
        ? 'No tickets have been sold yet.'
        : 'All $sold ticket${sold == 1 ? '' : 's'} sold (${formatPeso(event.grossRevenue)}) '
              'will be refunded automatically and every holder notified.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final p = FairTixPalette.of(ctx);
          return AdminDialog(
            title: 'Unpublish this event?',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminDialogText(
                    '"${event.title}" will be hidden from event goers but not deleted. '
                    '$refundNote',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: orgText(p, size: 14, height: 1.3),
                    cursorColor: p.accentLabel,
                    decoration: adminInputDecoration(
                      ctx,
                      label: 'Reason (shown to the organizer)',
                      hint: 'e.g. LGU permit is missing or expired',
                      errorText: showReasonError
                          ? 'A reason is required.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: AdminDialogText('Time to submit proper documents'),
                      ),
                      DropdownButton<int>(
                        value: deadlineDays,
                        dropdownColor: p.surface,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final d in const [3, 7, 14, 30])
                            DropdownMenuItem(
                              value: d,
                              child: Text(
                                '$d days',
                                style: orgText(p, size: 14),
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => deadlineDays = v ?? 7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const AdminDialogText(
                    'If the organizer does not comply in time, the event is cancelled.',
                    small: true,
                  ),
                ],
              ),
            ),
            actions: [
              AdminDialogButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(ctx, false),
              ),
              AdminDialogButton(
                label: 'Unpublish',
                color: p.danger,
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    setDialogState(() => showReasonError = true);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          );
        },
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;
    await _changeStatus(
      event,
      () async {
        await AdminEventService.instance.unpublishEvent(
          event.id,
          reason: reason,
          deadlineDays: deadlineDays,
        );
      },
      sold == 0
          ? 'Event unpublished. The organizer has $deadlineDays days to comply.'
          : 'Event unpublished and ticket holders refunded. The organizer has $deadlineDays days to comply.',
    );
  }

  Future<void> _republishEvent(AdminEventSummary event) async {
    final p = FairTixPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminDialog(
        title: 'Republish this event?',
        content: AdminDialogText(
          '"${event.title}" will be visible and on sale again. Make sure you reviewed '
          'the new documents first. Previously refunded tickets are not restored.',
        ),
        actions: [
          AdminDialogButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AdminDialogButton(
            label: 'Republish',
            color: p.success,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _changeStatus(
      event,
      () => AdminEventService.instance.republishEvent(event.id),
      'Event republished.',
    );
  }

  Future<void> _changeStatus(
    AdminEventSummary event,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busyEventId = event.id);
    try {
      await action();
      await _load(showSpinner: false);
      _toast(successMessage);
    } on AdminEventServiceException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyEventId = null);
    }
  }

  Future<void> _exportCsv() async {
    final rows = _filtered;
    if (rows.isEmpty) {
      _toast('There are no events to export.');
      return;
    }
    final csv = toCsv([
      [
        'Event',
        'Organizer',
        'Venue',
        'Dates',
        'Status',
        'Tickets Sold',
        'Capacity',
        'Gross Ticket Sales',
      ],
      for (final e in rows)
        [
          csvSafe(e.title),
          csvSafe(e.organizerName),
          csvSafe(e.venue),
          e.dateLabel,
          e.statusLabel,
          e.ticketsSold,
          e.ticketsTotal,
          e.grossRevenue.toStringAsFixed(2),
        ],
    ]);
    final saved = await saveCsvFile(
      fileName: 'fairtix-events-${formatIsoDate(DateTime.now())}.csv',
      csv: csv,
    );
    _toast(saved ? 'Events exported.' : 'Export canceled.');
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      active: AdminNavItem.eventsTickets,
      title: 'Events & Tickets',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = FairTixPalette.of(context);
    // Cancelled events are being refunded, so they don't count as sales.
    final live = _events.where((e) => e.status != 'canceled').toList();
    final published = _events.where((e) => e.status == 'published').length;
    final ticketsSold = live.fold<int>(0, (sum, e) => sum + e.ticketsSold);
    final gross = live.fold<double>(0, (sum, e) => sum + e.grossRevenue);
    final filtered = _filtered;
    final ready = !_isLoading && _loadError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Events & Tickets',
          subtitle:
              'Every organizer\'s events with real sales, plus cancel and unpublish controls.',
          actions: [
            AdminIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh data',
              loading: _isLoading,
              onPressed: _isLoading ? null : _load,
            ),
            // Same published catalogue event goers see, view-only.
            AdminHeaderButton(
              icon: Icons.explore_outlined,
              label: 'Browse Published Events',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminBrowseEventsScreen(),
                ),
              ),
            ),
            AdminHeaderButton(
              icon: Icons.download_outlined,
              label: 'Export CSV',
              onPressed: _isLoading ? null : _exportCsv,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminSummaryRow(
          cards: [
            AdminSummaryCard(
              icon: Icons.event_outlined,
              color: p.accentLabel,
              label: 'Total Events',
              value: '${_events.length}',
              caption: '$published published',
            ),
            AdminSummaryCard(
              icon: Icons.confirmation_number_outlined,
              color: p.accentLabel,
              label: 'Tickets Sold',
              value: '$ticketsSold',
              caption: 'Excludes cancelled events',
            ),
            AdminSummaryCard(
              icon: Icons.payments_outlined,
              color: p.success,
              label: 'Gross Ticket Sales',
              value: formatPeso(gross),
              caption: 'Before platform fees',
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminFilterChips(
          labels: _statusFilters,
          selected: _statusFilters.indexOf(_statusFilter),
          counts: [for (final f in _statusFilters) ready ? _countFor(f) : null],
          onSelected: (i) => setState(() => _statusFilter = _statusFilters[i]),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminSearchField(
            hint: 'Search event, organizer or venue',
            width: 320,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: p.accentLabel,
                        ),
                      ),
                    )
                  : _loadError != null
                  ? AdminErrorBox(message: _loadError!, onRetry: _load)
                  : _buildTable(filtered),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<AdminEventSummary> filtered) {
    if (filtered.isEmpty) {
      return AdminEmptyState(
        icon: Icons.event_busy_outlined,
        title: _events.isEmpty
            ? 'No events yet'
            : 'No events match your filters',
        hint: _events.isEmpty
            ? 'Events will appear here once organizers create them.'
            : 'Try a different search or status.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final p = FairTixPalette.of(context);
        final wide = constraints.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              const AdminTableHeader(
                labels: [
                  'Event',
                  'Organizer',
                  'Date',
                  'Sold',
                  'Status',
                  'Actions',
                ],
                flex: _flex,
              ),
            for (final event in filtered)
              _EventRow(
                event: event,
                wide: wide,
                flex: _flex,
                expanded: _expanded.contains(event.id),
                busy: _busyEventId == event.id,
                onToggle: () => setState(() {
                  if (!_expanded.add(event.id)) _expanded.remove(event.id);
                }),
                onUnpublish: () => _unpublishEvent(event),
                onRepublish: () => _republishEvent(event),
                onViewDocuments: () => _viewDocuments(event),
                onCancel: () => _cancelEvent(event),
              ),
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Showing ${filtered.length} of ${_events.length} events',
                style: orgText(p, size: 12, color: p.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}

AdminBadge _statusBadge(AdminEventSummary event) => switch (event.status) {
  'draft' when event.isUnpublished => AdminBadge.danger(event.statusLabel),
  'published' => AdminBadge.success(event.statusLabel),
  'canceled' => AdminBadge.danger(event.statusLabel),
  'completed' => AdminBadge.info(event.statusLabel),
  _ => AdminBadge.neutral(event.statusLabel),
};

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.wide,
    required this.flex,
    required this.expanded,
    required this.busy,
    required this.onToggle,
    required this.onUnpublish,
    required this.onRepublish,
    required this.onViewDocuments,
    required this.onCancel,
  });

  final AdminEventSummary event;
  final bool wide;
  final List<int> flex;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onUnpublish;
  final VoidCallback onRepublish;
  final VoidCallback onViewDocuments;
  final VoidCallback onCancel;

  Widget _actions(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AdminRowAction(
          label: expanded ? 'Hide tiers' : 'Tiers',
          onPressed: onToggle,
        ),
        AdminRowAction(label: 'Documents', onPressed: onViewDocuments),
        if (event.canRepublish)
          AdminRowAction(
            label: 'Republish',
            color: p.success,
            onPressed: busy ? null : onRepublish,
          ),
        if (event.canUnpublish)
          AdminRowAction(
            label: 'Unpublish',
            onPressed: busy ? null : onUnpublish,
          ),
        if (event.canCancel)
          AdminRowAction(
            label: busy ? 'Working...' : 'Cancel',
            color: p.danger,
            onPressed: busy ? null : onCancel,
          ),
      ],
    );
  }

  Widget _tierDetails(BuildContext context) {
    final p = FairTixPalette.of(context);
    TextStyle cell({bool bold = false, bool muted = false}) => orgText(
      p,
      size: 13,
      weight: bold ? FontWeight.w600 : FontWeight.w400,
      color: muted ? p.textSecondary : p.textPrimary,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      color: p.progressTrack,
      child: event.tiers.isEmpty
          ? Text(
              'No ticket tiers.',
              style: orgText(p, size: 13, color: p.textSecondary),
            )
          : Column(
              children: [
                for (final tier in event.tiers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(tier.label, style: cell(bold: true)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(formatPeso(tier.price), style: cell()),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${tier.sold} / ${tier.total} sold',
                            style: cell(),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatPeso(tier.revenue),
                            textAlign: TextAlign.right,
                            style: cell(muted: true),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    final Widget row;
    if (wide) {
      row = AdminTableRow(
        children: [
          Expanded(
            flex: flex[0],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: orgText(
                      p,
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    event.venue,
                    style: orgText(
                      p,
                      size: 12,
                      color: p.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  if (event.complianceLabel != null)
                    Text(
                      event.complianceLabel!,
                      style: orgText(
                        p,
                        size: 12,
                        color: p.danger,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          ),
          adminCell(context, flex[1], event.organizerName),
          adminCell(context, flex[2], event.dateLabel),
          adminCell(context, flex[3], event.soldLabel),
          Expanded(
            flex: flex[4],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(event),
            ),
          ),
          Expanded(flex: flex[5], child: _actions(context)),
        ],
      );
    } else {
      row = Container(
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
                _statusBadge(event),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${event.organizerName} \u2022 ${event.venue}',
              style: orgText(p, size: 12, color: p.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '${event.dateLabel} \u2022 ${event.soldLabel} sold',
              style: orgText(p, size: 13),
            ),
            if (event.complianceLabel != null)
              Text(
                event.complianceLabel!,
                style: orgText(p, size: 12, color: p.danger),
              ),
            const SizedBox(height: 12),
            _actions(context),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, if (expanded) _tierDetails(context)],
    );
  }
}
