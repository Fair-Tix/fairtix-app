import 'package:flutter/material.dart';

import '../../services/admin_event_service.dart';
import '../../services/csv_export.dart';
import '../../widgets/admin_document_viewer.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../organizer/app_colors.dart';
import '../user/all_events_screen.dart';

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
  State<AdminEventsTicketsScreen> createState() => _AdminEventsTicketsScreenState();
}

class _AdminEventsTicketsScreenState extends State<AdminEventsTicketsScreen> {
  static const _statusFilters = ['All', 'Published', 'Unpublished', 'Draft', 'Cancelled', 'Completed'];

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
      if (_statusFilter != 'All' && e.statusLabel != _statusFilter) return false;
      if (query.isEmpty) return true;
      return '${e.title} ${e.organizerName} ${e.venue}'.toLowerCase().contains(query);
    }).toList();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelEvent(AdminEventSummary event) async {
    final sold = event.ticketsSold;
    final body = sold == 0
        ? 'No tickets have been sold for "${event.title}". It will be marked as cancelled.'
        : 'This cancels "${event.title}" and all $sold ticket${sold == 1 ? '' : 's'} sold '
              '(${formatPeso(event.grossRevenue)}). A refund is created for each purchase, '
              'any resale listings are closed, and every ticket holder is notified. '
              'This cannot be undone.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            child: const Text('Cancel Event'),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Unpublish this event?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${event.title}" will be hidden from event goers but not deleted. '
                  '$refundNote',
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason (shown to the organizer)',
                    hintText: 'e.g. LGU permit is missing or expired',
                    errorText: showReasonError ? 'A reason is required.' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Time to submit proper documents',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    DropdownButton<int>(
                      value: deadlineDays,
                      items: [
                        for (final d in const [3, 7, 14, 30])
                          DropdownMenuItem(value: d, child: Text('$d days')),
                      ],
                      onChanged: (v) => setDialogState(() => deadlineDays = v ?? 7),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'If the organizer does not comply in time, the event is cancelled.',
                  style: TextStyle(fontSize: 11, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  setDialogState(() => showReasonError = true);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Unpublish'),
            ),
          ],
        ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Republish this event?'),
        content: Text(
          '"${event.title}" will be visible and on sale again. Make sure you reviewed '
          'the new documents first. Previously refunded tickets are not restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Republish'),
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
      ['Event', 'Organizer', 'Venue', 'Dates', 'Status', 'Tickets Sold', 'Capacity', 'Gross Ticket Sales'],
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
    // Cancelled events are being refunded, so they don't count as sales.
    final live = _events.where((e) => e.status != 'canceled').toList();
    final published = _events.where((e) => e.status == 'published').length;
    final ticketsSold = live.fold<int>(0, (sum, e) => sum + e.ticketsSold);
    final gross = live.fold<double>(0, (sum, e) => sum + e.grossRevenue);
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Events & Tickets', style: AppTextStyles.h2)),
            IconButton(
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 4),
            // Same published catalogue event goers see, view-only.
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AllEventsScreen(readOnly: true)),
              ),
              icon: const Icon(Icons.explore_outlined, size: 14),
              label: const Text('Browse Published Events', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
              ),
            ),
            const SizedBox(width: 8),
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
              icon: Icons.event_outlined,
              color: AppColors.primaryPurple,
              label: 'Total Events',
              value: '${_events.length}',
              caption: '$published published',
            ),
            AdminSummaryCard(
              icon: Icons.confirmation_number_outlined,
              color: AppColors.infoBlue,
              label: 'Tickets Sold',
              value: '$ticketsSold',
              caption: 'Excludes cancelled events',
            ),
            AdminSummaryCard(
              icon: Icons.payments_outlined,
              color: AppColors.successGreen,
              label: 'Gross Ticket Sales',
              value: formatPeso(gross),
              caption: 'Before platform fees',
            ),
          ],
        ),
        const SizedBox(height: 18),
        AdminCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search event, organizer or venue...',
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
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox.shrink(),
                items: [
                  for (final f in _statusFilters)
                    DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))),
                ],
                onChanged: (value) => setState(() => _statusFilter = value ?? 'All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdminCard(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              : _loadError != null
              ? AdminErrorBox(message: _loadError!, onRetry: _load)
              : _buildTable(filtered),
        ),
      ],
    );
  }

  Widget _buildTable(List<AdminEventSummary> filtered) {
    if (filtered.isEmpty) {
      return AdminEmptyState(
        icon: Icons.event_busy_outlined,
        title: _events.isEmpty ? 'No events yet' : 'No events match your filters',
        hint: _events.isEmpty
            ? 'Events will appear here once organizers create them.'
            : 'Try a different search or status.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Column(
          children: [
            if (wide)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFFBFBFD),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('EVENT', style: adminHeaderStyle)),
                    Expanded(flex: 2, child: Text('ORGANIZER', style: adminHeaderStyle)),
                    Expanded(flex: 2, child: Text('DATE', style: adminHeaderStyle)),
                    Expanded(child: Text('SOLD', style: adminHeaderStyle)),
                    Expanded(child: Text('STATUS', style: adminHeaderStyle)),
                    SizedBox(width: 300, child: Text('ACTIONS', style: adminHeaderStyle)),
                  ],
                ),
              ),
            const Divider(height: 1),
            for (final event in filtered)
              _EventRow(
                event: event,
                wide: wide,
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${filtered.length} of ${_events.length} events',
                  style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                ),
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
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onUnpublish;
  final VoidCallback onRepublish;
  final VoidCallback onViewDocuments;
  final VoidCallback onCancel;

  Widget _actions() => Wrap(
    spacing: 2,
    children: [
      TextButton(
        onPressed: onToggle,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
        child: Text(expanded ? 'Hide tiers' : 'Tiers', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      TextButton(
        onPressed: onViewDocuments,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
        child: const Text('Documents', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      if (event.canRepublish)
        TextButton(
          onPressed: busy ? null : onRepublish,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            foregroundColor: AppColors.successGreen,
          ),
          child: const Text('Republish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      if (event.canUnpublish)
        TextButton(
          onPressed: busy ? null : onUnpublish,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
          child: const Text('Unpublish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      if (event.canCancel)
        TextButton(
          onPressed: busy ? null : onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            foregroundColor: AppColors.dangerRed,
          ),
          child: Text(busy ? 'Working...' : 'Cancel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
    ],
  );

  Widget _tierDetails() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    color: const Color(0xFFFBFBFD),
    child: event.tiers.isEmpty
        ? const Text('No ticket tiers.', style: TextStyle(color: AppColors.textGray, fontSize: 11))
        : Column(
            children: [
              for (final tier in event.tiers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(tier.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text(formatPeso(tier.price), style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 2, child: Text('${tier.sold} / ${tier.total} sold', style: const TextStyle(fontSize: 11))),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatPeso(tier.revenue),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) {
    final row = wide
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text(event.venue, style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                      if (event.complianceLabel != null)
                        Text(event.complianceLabel!, style: const TextStyle(fontSize: 10.5, color: AppColors.dangerRed)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text(event.organizerName, style: const TextStyle(fontSize: 11))),
                Expanded(flex: 2, child: Text(event.dateLabel, style: const TextStyle(fontSize: 11))),
                Expanded(child: Text(event.soldLabel, style: const TextStyle(fontSize: 11))),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: _statusBadge(event))),
                SizedBox(width: 300, child: _actions()),
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
                    Expanded(child: Text(event.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                    _statusBadge(event),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${event.organizerName} \u2022 ${event.venue}', style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                const SizedBox(height: 4),
                Text('${event.dateLabel} \u2022 ${event.soldLabel} sold', style: const TextStyle(fontSize: 11)),
                if (event.complianceLabel != null)
                  Text(event.complianceLabel!, style: const TextStyle(fontSize: 10.5, color: AppColors.dangerRed)),
                const SizedBox(height: 6),
                _actions(),
              ],
            ),
          );

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight))),
      child: Column(children: [row, if (expanded) _tierDetails()]),
    );
  }
}
