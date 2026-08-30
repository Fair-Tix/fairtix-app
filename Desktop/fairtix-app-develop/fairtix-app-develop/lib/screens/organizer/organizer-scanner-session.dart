import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import '../../services/event_repository.dart';
import 'organizer-scaffold.dart';

/// Live scanner session screen for a single event.
///
/// TODO(backend): Once entry-staff scanning is wired to Cloud Firestore
/// (see Chapter III Data Dictionary: Scanner_Session / QR Scan Logs), the
/// session link/PIN should come from a real `Scanner_Session` record and
/// the activity feed below should stream from `QR Scan Logs` in real time
/// instead of showing an empty state.
class OrganizerScannerSessionScreen extends StatelessWidget {
  final String eventId;

  const OrganizerScannerSessionScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final event = EventRepository.instance.getById(eventId);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;

    return OrganizerScaffold(
      pageTitle: 'Live Scanner Session',
      activeItem: OrganizerNavItem.myEvents,
      topBarTrailing: OutlinedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('End Session?'),
              content: const Text(
                'This will immediately disable the scanner link and PIN for '
                'all entry staff.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scanner session ended.'),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('End Session',
                      style: TextStyle(color: AppColors.dangerRed)),
                ),
              ],
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dangerRed,
          side: const BorderSide(color: AppColors.dangerRed),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('End Session'),
      ),
      body: event == null
          ? const Center(
              child: Text('This event could not be found.',
                  style: AppTextStyles.h3),
            )
          : isWide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _leftColumn(context, event.name)),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: _activityCard()),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _leftColumn(context, event.name),
                    const SizedBox(height: 24),
                    _activityCard(),
                  ],
                ),
    );
  }

  Widget _leftColumn(BuildContext context, String eventName) {
    // TODO(backend): source the link/PIN from a real Scanner_Session record
    // instead of deriving a placeholder from the event id.
    final sessionSlug = eventId.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'), '-');
    final scannerUrl = 'https://fairtix.app/scan/$sessionSlug';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Session Info',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('EVENT'),
              const SizedBox(height: 4),
              Text(eventName, style: AppTextStyles.h3),
              const SizedBox(height: 16),
              _label('ACTIVE SCANNERS'),
              const SizedBox(height: 4),
              const Text('0', style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Session Access',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('SCANNER LINK'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 16, color: AppColors.textGray),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scannerUrl,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: scannerUrl));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Scanner link copied to clipboard.'),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                    ),
                    child: const Text('Copy Link'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Share the link and PIN with entry staff separately.',
                style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _card(
          title: 'Scan Velocity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Text('0',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      )),
                  SizedBox(width: 8),
                  Text('scans/min', style: AppTextStyles.bodyGray),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primaryPurple),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityCard() {
    return _card(
      title: 'Live Activity Feed',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.qr_code_scanner_outlined,
                size: 40, color: AppColors.textGray),
            const SizedBox(height: 12),
            Text(
              'No scans yet. Entries will appear here as attendees are '
              'scanned in.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyGray,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textGray,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.primaryPurple)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
