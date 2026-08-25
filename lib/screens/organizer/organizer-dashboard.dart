import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import '../../services/organizer_session.dart';
import 'organizer-scaffold.dart';
import 'organizer-create-event.dart';
import 'organizer-send-announcement.dart';
import 'organizer-cancel-event.dart';
import 'organizer-edit-event.dart';
import 'organizer-my-events.dart';
import 'organizer-scanner-session.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 720;
    final events = EventRepository.instance.events;
    final organizationName =
        OrganizerSession.instance.account?.organizationName ?? 'Organizer';

    return OrganizerScaffold(
      pageTitle: 'Organizer Dashboard',
      activeItem: OrganizerNavItem.dashboard,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome + action buttons
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back,', style: AppTextStyles.bodyGray),
                  Text(organizationName, style: AppTextStyles.h1),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrganizerSendAnnouncementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.campaign_outlined, size: 18, color: AppColors.primaryPurple),
                    label: const Text('Send Announcement'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrganizerCreateEventScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Stat cards — computed from real event data (starts at zero for a
          // brand-new organizer; no hardcoded sample totals).
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _StatCard(
                  icon: Icons.event_available_outlined,
                  label: 'Total Events',
                  value: '${events.length}',
                ),
                _StatCard(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Tickets Sold',
                  value: '${EventRepository.instance.totalTicketsSold}',
                ),
                _StatCard(
                  icon: Icons.paid_outlined,
                  label: 'Revenue',
                  value:
                      '\u20B1${EventRepository.instance.totalGrossRevenue.toStringAsFixed(0)}',
                  valueColor: AppColors.successGreen,
                ),
              ];
              if (isNarrow) {
                return Column(
                  children: cards
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: c,
                          ))
                      .toList(),
                );
              }
              return Row(
                children: cards
                    .map((c) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: c,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // My events table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Events', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrganizerMyEventsScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      children: [
                        const Icon(Icons.event_note_outlined,
                            size: 40, color: AppColors.textGray),
                        const SizedBox(height: 12),
                        Text(
                          'No events yet. Create your first event to get started.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyGray,
                        ),
                      ],
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints(context),
                      ),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                        columns: const [
                          DataColumn(label: Text('EVENT NAME')),
                          DataColumn(label: Text('DATE')),
                          DataColumn(label: Text('VENUE')),
                          DataColumn(label: Text('SOLD')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: events
                            .take(5)
                            .map((event) => _eventRow(context, event))
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double constraints(BuildContext context) =>
      MediaQuery.of(context).size.width - 260 - 64;

  DataRow _eventRow(BuildContext context, OrganizerEvent event) {
    final isPublished = event.status == EventStatus.published;
    return DataRow(cells: [
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined,
                  size: 18, color: AppColors.primaryPurple),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                event.name,
                style: AppTextStyles.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
      DataCell(Text(event.date, style: AppTextStyles.body)),
      DataCell(Text(event.venue, style: AppTextStyles.body)),
      DataCell(Text(event.soldLabel, style: AppTextStyles.label)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isPublished
                ? AppColors.successGreenBg
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            event.status.label,
            style: TextStyle(
              color:
                  isPublished ? AppColors.successGreen : AppColors.textGray,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrganizerEditEventScreen(eventId: event.id),
                  ),
                );
              },
              child: const Text('Manage',
                  style: TextStyle(color: AppColors.textDark)),
            ),
            if (event.status == EventStatus.published)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrganizerScannerSessionScreen(eventId: event.id),
                    ),
                  );
                },
                child: const Text('Scan',
                    style: TextStyle(color: AppColors.primaryPurple)),
              ),
            OutlinedButton(
              onPressed: event.status == EventStatus.cancelled
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrganizerCancelEventScreen(eventId: event.id),
                        ),
                      );
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
                side: const BorderSide(color: AppColors.dangerRed),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodyGray),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.h2.copyWith(color: valueColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}