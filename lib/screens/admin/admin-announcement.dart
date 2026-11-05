import 'package:flutter/material.dart';

import '../../services/admin_user_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/organizer_ui.dart';

/// Opens the "Create Announcement" modal (used by the Dashboard header).
Future<void> showAdminAnnouncementDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AnnouncementDialog(),
  );
}

/// Standalone page version of the announcement form. The Dashboard now opens
/// [showAdminAnnouncementDialog] instead; this page shares the same form.
class AdminAnnouncementScreen extends StatelessWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final p = FairTixPalette.of(context);
    return AdminShell(
      active: AdminNavItem.dashboard,
      title: 'Platform Announcement',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(title: 'Platform Announcement'),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: AdminCard(
              padding: EdgeInsets.all(isWide ? 28 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New Platform Announcement',
                    style: orgText(p, size: 18, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Broadcast a message to all FairTix users and organizers',
                    style: orgText(p, size: 13, color: p.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  const AdminAnnouncementForm(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: const _PlatformWideNotice(),
          ),
        ],
      ),
    );
  }
}

/// The modal: header with a close button, the form, then the platform-wide
/// notice. Closes itself once the announcement was sent.
class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Announcement',
                          style: orgText(p, size: 20, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Broadcast a message to all FairTix users and organizers',
                          style: orgText(
                            p,
                            size: 13,
                            color: p.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AdminAnnouncementForm(
                onSent: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              const _PlatformWideNotice(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformWideNotice extends StatelessWidget {
  const _PlatformWideNotice();

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.warningSurface,
        border: Border.all(color: p.warningBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.volume_off_outlined, size: 18, color: p.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This will be sent platform-wide to all verified users and organizers.',
              style: orgText(p, size: 13, color: p.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subject + message fields and the Send button. [onSent] runs after a
/// successful send (the modal uses it to close itself).
class AdminAnnouncementForm extends StatefulWidget {
  const AdminAnnouncementForm({super.key, this.onSent});

  final VoidCallback? onSent;

  @override
  State<AdminAnnouncementForm> createState() => _AdminAnnouncementFormState();
}

class _AdminAnnouncementFormState extends State<AdminAnnouncementForm> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    super.dispose();
  }

  void _onMessageChanged() => setState(() {});

  /// Delivers the announcement as an in-app notification to every verified,
  /// active buyer and organizer (the `send_announcement` RPC, see
  /// supabase/organizer_event_functions.sql), then reports how many people
  /// received it.
  Future<void> _sendAnnouncement() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSending = true);
    // Captured up front so the result still shows if the modal is closed
    // while the request is running.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await AdminUserService.instance.sendAnnouncement(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        audience: 'all',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No eligible users to notify yet.'
                : 'Announcement sent to $count user${count == 1 ? '' : 's'}.',
          ),
        ),
      );
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      widget.onSent?.call();
    } on AdminUserServiceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('SUBJECT'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _subjectController,
            cursorColor: p.accentLabel,
            style: orgText(p, size: 14, height: 1.4),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Subject is required'
                : null,
            decoration: _inputDecoration(
              'e.g. Scheduled maintenance on July 10',
            ),
          ),
          const SizedBox(height: 18),
          _label('MESSAGE'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _messageController,
            maxLength: 1000,
            maxLines: 6,
            cursorColor: p.accentLabel,
            style: orgText(p, size: 14, height: 1.4),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Message is required'
                : null,
            decoration:
                _inputDecoration(
                  'Write your platform-wide message here...',
                ).copyWith(
                  counterText: '${_messageController.text.length} / 1000',
                  counterStyle: orgText(p, size: 12, color: p.textSecondary),
                ),
          ),
          const SizedBox(height: 18),
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
                    size: 16,
                    color: p.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audience: All verified users & organizers',
                    style: orgText(p, size: 12, color: p.textSecondary),
                  ),
                ],
              ),
              AdminHeaderButton(
                icon: Icons.send_outlined,
                label: _isSending ? 'Sending...' : 'Send Announcement',
                filled: true,
                onPressed: _isSending ? null : _sendAnnouncement,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    final p = FairTixPalette.of(context);
    return Text(
      text,
      style: orgText(
        p,
        size: 11,
        weight: FontWeight.w700,
        color: p.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final p = FairTixPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: orgText(p, size: 14, color: p.textSecondary),
      errorStyle: orgText(p, size: 12, color: p.danger),
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.accentLabel),
      errorBorder: border(p.danger),
      focusedErrorBorder: border(p.danger),
    );
  }
}
