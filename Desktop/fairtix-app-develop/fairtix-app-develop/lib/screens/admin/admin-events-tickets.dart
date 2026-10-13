import 'package:flutter/material.dart';

import '../../models/organizer_event.dart';
import '../../services/admin_session.dart';
import '../../services/event_repository.dart';
import '../organizer/app_colors.dart';
import 'admin-dashboard.dart';
import 'admin-route.dart';
import 'admin-accounts.dart';
import 'admin-fraud-alerts.dart';
import 'admin-organizer-applications.dart';
import 'admin-login.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminEventsTicketsScreen extends StatefulWidget {
  const AdminEventsTicketsScreen({super.key});

  @override
  State<AdminEventsTicketsScreen> createState() =>
      _AdminEventsTicketsScreenState();
}

class _AdminEventsTicketsScreenState extends State<AdminEventsTicketsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  String _organizerFilter = 'All Organizers';
  bool _filtersApplied = false;
  final Set<String> _expandedEvents = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OrganizerEvent> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    return EventRepository.instance.events.where((event) {
      final matchesSearch =
          query.isEmpty ||
          event.name.toLowerCase().contains(query) ||
          event.venue.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'All' || event.status.label == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      drawer: isWide ? null : Drawer(child: _buildSidebar()),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 180, child: _buildSidebar()),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWide),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, _, child) {
                      final events = _filteredEvents;
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(isWide ? 18 : 14),
                        child: _buildContent(context, events, isWide),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    const items = [
      (Icons.grid_view_rounded, 'Dashboard'),
      (Icons.business_outlined, 'Organizer Applications'),
      (Icons.people_outline, 'Accounts'),
      (Icons.calendar_today_outlined, 'Events & Tickets'),
      (Icons.swap_vert_rounded, 'Resale Monitoring'),
      (Icons.shield_outlined, 'Fraud Alerts'),
      (Icons.bar_chart_rounded, 'Revenue & Reports'),
      (Icons.settings_outlined, 'Platform Settings'),
      (Icons.person_outline, 'Profile'),
    ];
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';

    return Container(
      color: const Color(0xFFF3F1FD),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: _AdminLogo(),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 14),
            for (var index = 0; index < items.length; index++)
              _SidebarItem(
                icon: items[index].$1,
                label: items[index].$2,
                selected: index == 3,
                onTap: () {
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminDashboardScreen()),
                    );
                  } else if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminOrganizerApplicationsScreen()),
                    );
                  } else if (index == 2) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminAccountsScreen()),
                    );
                  } else if (index == 4) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminResaleMonitoringScreen()),
                    );
                  } else if (index == 5) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminFraudAlertsScreen()),
                    );
                  } else if (index == 6) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminRevenueReportsScreen()),
                    );
                  } else if (index == 7) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminPlatformSettingsScreen()),
                    );
                  } else if (index == 8) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminProfileScreen()),
                    );
                  }
                },
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFE8E6F1),
                    child: Icon(
                      Icons.person,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin', style: AppTextStyles.label),
                        Text(
                          currentEmail,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _confirmLogout,
                    icon: const Icon(
                      Icons.logout,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                    tooltip: 'Log out',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to Log Out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted || shouldLogout != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 20),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const Text('Events Management', style: AppTextStyles.label),
          const Spacer(),
          const Icon(
            Icons.notifications_none,
            size: 19,
            color: AppColors.textGray,
          ),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFE8E6F1),
            child: Icon(Icons.person, size: 16, color: AppColors.textGray),
          ),
          if (isWide) ...[
            const SizedBox(width: 8),
            Text(
              AdminSession.instance.currentEmail ?? 'admin@fairtix.com',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<OrganizerEvent> events,
    bool isWide,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Events & Ticket Sales', style: AppTextStyles.h2),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportCsv(events),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildFilters(isWide),
        const SizedBox(height: 18),
        if (events.isEmpty) _emptyState() else _buildEventTable(events),
        const SizedBox(height: 16),
        Text(
          'Showing ${events.length} of ${EventRepository.instance.events.length} events',
          style: AppTextStyles.bodyGray,
        ),
      ],
    );
  }

  Widget _buildFilters(bool isWide) {
    final controls = [
      Expanded(
        flex: 3,
        child: TextField(
          controller: _searchController,
          decoration: _inputDecoration(
            'Search event name or venue...',
            Icons.search,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _dropdown(
          'Status',
          _statusFilter,
          ['All', 'Published', 'Draft', 'Cancelled', 'Completed'],
          (value) {
            setState(() => _statusFilter = value!);
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _dropdown('Organizer', _organizerFilter, ['All Organizers'], (
          value,
        ) {
          setState(() => _organizerFilter = value!);
        }),
      ),
      const SizedBox(width: 10),
      FilledButton(
        onPressed: () => setState(() => _filtersApplied = true),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: const Text('Apply Filters'),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: isWide
          ? Row(children: controls)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                controls[0],
                const SizedBox(height: 10),
                Row(children: controls.sublist(2)),
              ],
            ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textGray, fontSize: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.primaryPurple),
        ),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textGray),
        filled: true,
        fillColor: const Color(0xFFF8F7FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryPurple),
        ),
      );

  Widget _buildEventTable(List<OrganizerEvent> events) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFFBFBFD)),
          columns: const [
            DataColumn(label: Text('EVENT NAME')),
            DataColumn(label: Text('DATE')),
            DataColumn(label: Text('VENUE')),
            DataColumn(label: Text('TICKETS SOLD')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: [
            for (final event in events) ...[
              _eventRow(event),
              if (_expandedEvents.contains(event.id)) _tierBreakdownRow(event),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _tierBreakdownRow(OrganizerEvent event) {
    return DataRow(
      color: WidgetStateProperty.all(const Color(0xFFF8F7FC)),
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ticket Tier Breakdown',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  for (final tier in event.tiers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${tier.name}   |   ₱${tier.price.toStringAsFixed(0)}   |   ${tier.sold} sold / ${tier.quantity}   |   ₱${tier.grossRevenue.toStringAsFixed(0)} revenue',
                        style: AppTextStyles.body,
                      ),
                    ),
                  if (event.tiers.isEmpty)
                    const Text(
                      'No ticket tiers configured.',
                      style: AppTextStyles.bodyGray,
                    ),
                ],
              ),
            ),
          ),
        ),
        const DataCell(SizedBox.shrink()),
        const DataCell(SizedBox.shrink()),
        const DataCell(SizedBox.shrink()),
        const DataCell(SizedBox.shrink()),
        const DataCell(SizedBox.shrink()),
      ],
    );
  }

  DataRow _eventRow(OrganizerEvent event) {
    final expanded = _expandedEvents.contains(event.id);
    return DataRow(
      color: WidgetStateProperty.resolveWith(
        (_) => expanded ? const Color(0xFFF8F7FC) : null,
      ),
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.textGray,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    event.name,
                    style: AppTextStyles.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          onTap: () => setState(() {
            expanded
                ? _expandedEvents.remove(event.id)
                : _expandedEvents.add(event.id);
          }),
        ),
        DataCell(Text(event.date, style: AppTextStyles.body)),
        DataCell(Text(event.venue, style: AppTextStyles.body)),
        DataCell(Text(event.soldLabel, style: AppTextStyles.label)),
        DataCell(_statusBadge(event.status)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: expanded ? 'Hide ticket tiers' : 'Show ticket tiers',
                onPressed: () => setState(() {
                  expanded
                      ? _expandedEvents.remove(event.id)
                      : _expandedEvents.add(event.id);
                }),
                icon: Icon(
                  expanded
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.primaryPurple,
                ),
              ),
              IconButton(
                tooltip: 'Cancel event',
                onPressed: event.status == EventStatus.cancelled
                    ? null
                    : () => _cancelEvent(event),
                icon: const Icon(
                  Icons.cancel_outlined,
                  size: 18,
                  color: AppColors.dangerRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(EventStatus status) {
    final color = status == EventStatus.published
        ? AppColors.successGreen
        : status == EventStatus.cancelled
        ? AppColors.dangerRed
        : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(42),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.event_busy_outlined,
          size: 42,
          color: AppColors.textGray,
        ),
        const SizedBox(height: 12),
        Text(
          _filtersApplied
              ? 'No events match these filters.'
              : 'No events have been created yet.',
          style: AppTextStyles.bodyGray,
        ),
      ],
    ),
  );

  Future<void> _cancelEvent(OrganizerEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel event?'),
        content: Text(
          'Cancel ${event.name}? This changes its status to Cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      EventRepository.instance.cancelEvent(event.id);
      setState(() {});
    }
  }

  void _exportCsv(List<OrganizerEvent> events) {
    final csv = [
      'Event,Date,Venue,Tickets Sold,Status,Revenue',
      ...events.map(
        (event) =>
            '${event.name},${event.date},${event.venue},${event.soldLabel},${event.status.label},${event.grossRevenue.toStringAsFixed(2)}',
      ),
    ].join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV ready (${csv.length} characters).')),
    );
  }
}

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          Icons.confirmation_number_outlined,
          color: Colors.white,
          size: 14,
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        'FairTix',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
      ),
      const SizedBox(width: 3),
      const Text(
        'ADMIN',
        style: TextStyle(fontSize: 8, color: AppColors.textGray),
      ),
    ],
  );
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? AppColors.primaryPurple : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
