import 'package:flutter/material.dart';

import '../../services/access_control.dart';
import '../../services/organizer_announcement_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_account_ui.dart';
import '../../widgets/organizer_ui.dart';

/// Opens the "New Announcement" pop-up. Announcements are a subscription
/// feature, so this explains and returns without opening anything when the
/// organizer is locked out.
Future<void> showOrganizerAnnouncementDialog(BuildContext context) async {
  final allowed = await ensureOrganizerAccess(
    context,
    OrganizerRequirement.subscription,
  );
  if (!allowed || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _AnnouncementDialog(),
  );
}

/// Kept so any older route to the announcement screen still works: it opens
/// the pop-up over an empty page and closes itself when the pop-up closes.
class OrganizerSendAnnouncementScreen extends StatefulWidget {
  const OrganizerSendAnnouncementScreen({super.key});

  @override
  State<OrganizerSendAnnouncementScreen> createState() =>
      _OrganizerSendAnnouncementScreenState();
}

class _OrganizerSendAnnouncementScreenState
    extends State<OrganizerSendAnnouncementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showOrganizerAnnouncementDialog(context);
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: FairTixPalette.of(context).background);
  }
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  static const int _maxLength = 500;

  final _subject = TextEditingController();
  final _message = TextEditingController();

  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject.addListener(_refresh);
    _message.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending &&
      _subject.text.trim().isNotEmpty &&
      _message.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final count = await OrganizerAnnouncementService.instance.send(
        subject: _subject.text,
        message: _message.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No one has bought a ticket to your events yet, so there was '
                      'no one to send this to.'
                : 'Announcement sent to $count ticket holder'
                      '${count == 1 ? '' : 's'} via in-app, email, and push '
                      'notification.',
          ),
        ),
      );
    } on OrganizerAnnouncementException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  InputDecoration _decoration(FairTixPalette p, String hint, {bool multi = false}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: orgText(p, size: 15, color: p.textSecondary),
      counterText: '',
      filled: true,
      fillColor: p.background,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: multi ? 16 : 15,
      ),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.accentLabel, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final count = _message.text.length;

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Announcement',
                      style: orgText(p, size: 22, weight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const OrganizerNote(
                text:
                    'This will be sent to users who have purchased tickets '
                    'from you, via in-app, email, and push notification.',
              ),
              const SizedBox(height: 22),
              const OrganizerFieldLabel('Subject'),
              const SizedBox(height: 8),
              TextField(
                controller: _subject,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: orgText(p, size: 15),
                decoration: _decoration(
                  p,
                  'e.g. Important update for ticket holders',
                ),
              ),
              const SizedBox(height: 20),
              const OrganizerFieldLabel('Message'),
              const SizedBox(height: 8),
              TextField(
                controller: _message,
                minLines: 5,
                maxLines: 6,
                maxLength: _maxLength,
                style: orgText(p, size: 15, height: 1.45),
                decoration: _decoration(
                  p,
                  'Write your announcement here...',
                  multi: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$count / $_maxLength',
                    style: orgText(p, size: 12, color: p.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: orgText(p, size: 13, color: p.danger, height: 1.4),
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 14,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 18,
                        color: p.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          style: orgText(p, size: 14, color: p.textSecondary),
                          children: [
                            const TextSpan(text: 'Sending to: '),
                            TextSpan(
                              text: 'all ticket holders',
                              style: orgText(
                                p,
                                size: 14,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 110,
                        child: OrganizerSecondaryButton(
                          label: 'Cancel',
                          height: 46,
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Opacity(
                        opacity: _canSend ? 1 : 0.5,
                        child: SizedBox(
                          width: 190,
                          child: OrganizerPrimaryButton(
                            label: 'Send Announcement',
                            height: 46,
                            loading: _sending,
                            onPressed: _canSend ? _send : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
