import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import '../../services/event_repository.dart';
import '../../services/scanner_repository.dart';
import 'organizer-scaffold.dart';

/// Live scanner session screen for a single event.
///
/// On open, generates a real scanner session (link + 4-digit PIN) via
/// `generate_scanner_session` (see supabase/scanner_functions.sql) that
/// entry staff can use — no FairTix account needed on their end — through
/// the Staff PIN entry / QR Scan screens (lib/screens/staff/).
class OrganizerScannerSessionScreen extends StatefulWidget {
  final String eventId;

  const OrganizerScannerSessionScreen({super.key, required this.eventId});

  @override
  State<OrganizerScannerSessionScreen> createState() => _OrganizerScannerSessionScreenState();
}

class _OrganizerScannerSessionScreenState extends State<OrganizerScannerSessionScreen> {
  ScannerSession? _session;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateSession();
  }

  Future<void> _generateSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await ScannerRepository.instance.createSession(widget.eventId);
      if (!mounted) return;
      setState(() => _session = session);
    } on ScannerRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endSession(BuildContext context) async {
    final session = _session;
    if (session == null) {
      Navigator.pop(context);
      return;
    }
    try {
      await ScannerRepository.instance.endSession(session.sessionId);
    } on ScannerRepositoryException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not end session: ${e.message}')));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner session ended.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final event = EventRepository.instance.getById(widget.eventId);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;

    return OrganizerScaffold(
      pageTitle: 'Live Scanner Session',
      activeItem: OrganizerNavItem.myEvents,
      topBarTrailing: OutlinedButton(
        onPressed: _session == null
            ? null
            : () {
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
                          _endSession(context);
                        },
                        child: const Text('End Session', style: TextStyle(color: AppColors.dangerRed)),
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
          ? const Center(child: Text('This event could not be found.', style: AppTextStyles.h3))
          : _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, style: AppTextStyles.bodyGray, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _generateSession, child: const Text('Try again')),
                        ],
                      ),
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
    final session = _session!;

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
              _label('EXPIRES'),
              const SizedBox(height: 4),
              Text(_formatExpiry(session.expiresAt), style: AppTextStyles.body),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 16, color: AppColors.textGray),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.link,
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
                      await Clipboard.setData(ClipboardData(text: session.link));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scanner link copied to clipboard.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    child: const Text('Copy Link'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _label('ENTRY PIN'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      session.pin,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.primaryPurple),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: session.pin));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN copied to clipboard.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    child: const Text('Copy PIN'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Share the link and PIN with entry staff separately.',
                style: AppTextStyles.bodyGray.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _generateSession,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Regenerate Link & PIN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryPurple,
            side: const BorderSide(color: AppColors.primaryPurple),
            padding: const EdgeInsets.symmetric(vertical: 13),
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
            const Icon(Icons.qr_code_scanner_outlined, size: 40, color: AppColors.textGray),
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

  String _formatExpiry(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} \u2022 $hour12:$minute $period';
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
