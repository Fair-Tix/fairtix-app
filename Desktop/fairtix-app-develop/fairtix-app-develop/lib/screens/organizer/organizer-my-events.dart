import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../models/organizer_event.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';
import 'organizer-create-event.dart';
import 'organizer-edit-event.dart';
import 'organizer-cancel-event.dart';
import 'organizer-scanner-session.dart';

class OrganizerMyEventsScreen extends StatefulWidget {
  const OrganizerMyEventsScreen({super.key});

  @override
  State<OrganizerMyEventsScreen> createState() =>
      _OrganizerMyEventsScreenState();
}

class _OrganizerMyEventsScreenState extends State<OrganizerMyEventsScreen> {
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await EventRepository.instance.refresh();
    } on EventRepositoryException catch (e) {
      _loadError = e.message;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final events = EventRepository.instance.events;

    return OrganizerScaffold(
      pageTitle: 'My Events',
      activeItem: OrganizerNavItem.myEvents,
      topBarTrailing: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OrganizerCreateEventScreen(),
            ),
          );
          _load();
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Create Event'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          : _loadError != null
          ? _errorState(context, _loadError!)
          : events.isEmpty
          ? _emptyState(context)
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 260 - 64,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF9FAFB),
                    ),
                    columns: const [
                      DataColumn(label: Text('EVENT NAME')),
                      DataColumn(label: Text('DATE')),
                      DataColumn(label: Text('VENUE')),
                      DataColumn(label: Text('SOLD')),
                      DataColumn(label: Text('STATUS')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: events.map((e) => _row(context, e)).toList(),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _errorState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.dangerRed),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.dangerRed, fontSize: 12),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_note_outlined,
            size: 48,
            color: AppColors.textGray,
          ),
          const SizedBox(height: 16),
          const Text('No events yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Create your first event and it will show up here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyGray,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrganizerCreateEventScreen(),
                ),
              );
              _load();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, OrganizerEvent e) {
    final isPublished = e.status == EventStatus.published;
    final bannerUrl = EventRepository.instance.resolveBannerUrl(
      e.bannerImageUrl,
    );
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bannerUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    bannerUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: AppColors.primaryPurple,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: AppColors.primaryPurple,
                  ),
                ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  e.name,
                  style: AppTextStyles.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(e.date, style: AppTextStyles.body)),
        DataCell(Text(e.venue, style: AppTextStyles.body)),
        DataCell(Text(e.soldLabel, style: AppTextStyles.label)),
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
              e.status.label,
              style: TextStyle(
                color: isPublished
                    ? AppColors.successGreen
                    : AppColors.textGray,
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
                      builder: (_) => OrganizerEditEventScreen(eventId: e.id),
                    ),
                  );
                },
                child: const Text(
                  'Manage',
                  style: TextStyle(color: AppColors.textDark),
                ),
              ),
              if (e.status == EventStatus.published)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrganizerScannerSessionScreen(eventId: e.id),
                      ),
                    );
                  },
                  child: const Text(
                    'Scan',
                    style: TextStyle(color: AppColors.primaryPurple),
                  ),
                ),
              OutlinedButton(
                onPressed: e.status == EventStatus.cancelled
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrganizerCancelEventScreen(eventId: e.id),
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                  side: const BorderSide(color: AppColors.dangerRed),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
