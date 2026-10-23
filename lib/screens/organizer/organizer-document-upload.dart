import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-application-submitted.dart';

/// Shown right after an organizer's first successful login if their
/// proof-of-organization documents never made it to Storage at registration
/// time (Mahilum styling, same look as the Registration card).
///
/// Why this screen exists: registration now uploads both documents right
/// after the email code is verified (see `organizer-otp-verification.dart`),
/// but an account created earlier, or an upload that failed, can still be
/// missing one. [OrganizerLoginScreen] and [organizerLandingFor] check
/// `OrganizerAccount.hasSubmittedDocuments` and route here if either file is
/// missing, using the now-real session to upload them via
/// [OrganizerAuthService.uploadOrganizerDocument].
class OrganizerDocumentUploadScreen extends StatefulWidget {
  const OrganizerDocumentUploadScreen({super.key, required this.account});

  final OrganizerAccount account;

  @override
  State<OrganizerDocumentUploadScreen> createState() =>
      _OrganizerDocumentUploadScreenState();
}

class _OrganizerDocumentUploadScreenState
    extends State<OrganizerDocumentUploadScreen> {
  // Slot 1: government / school ID (stored as `venue_proof`).
  Uint8List? _venueProofBytes;
  String? _venueProofFileName;
  String? _venueProofExt;

  // Slot 2: proof of organization (stored as `event_permit`).
  Uint8List? _permitBytes;
  String? _permitFileName;
  String? _permitExt;

  bool _isSubmitting = false;
  String? _errorText;

  bool get _needsVenueProof => widget.account.venueProofUrl == null;
  bool get _needsPermit => widget.account.eventPermitUrl == null;

  Future<void> _pickDocument({required bool isVenueProof}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read that file. Please try another one.'),
        ),
      );
      return;
    }

    final ext = (file.extension ?? 'pdf').toLowerCase();
    setState(() {
      if (isVenueProof) {
        _venueProofBytes = bytes;
        _venueProofFileName = file.name;
        _venueProofExt = ext;
      } else {
        _permitBytes = bytes;
        _permitFileName = file.name;
        _permitExt = ext;
      }
    });
  }

  bool get _canSubmit {
    final venueOk = !_needsVenueProof || _venueProofBytes != null;
    final permitOk = !_needsPermit || _permitBytes != null;
    return venueOk && permitOk;
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    var updated = widget.account;

    try {
      if (_needsVenueProof && _venueProofBytes != null) {
        final path = await OrganizerAuthService.instance
            .uploadOrganizerDocument(
              docKind: 'venue_proof',
              bytes: _venueProofBytes!,
              fileExtension: _venueProofExt ?? 'pdf',
            );
        updated = updated.copyWith(venueProofUrl: path);
      }
      if (_needsPermit && _permitBytes != null) {
        final path = await OrganizerAuthService.instance
            .uploadOrganizerDocument(
              docKind: 'event_permit',
              bytes: _permitBytes!,
              fileExtension: _permitExt ?? 'pdf',
            );
        updated = updated.copyWith(eventPermitUrl: path);
      }
    } on OrganizerAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.message;
      });
      return;
    }

    OrganizerSession.instance.updateAccount(updated);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganizerApplicationSubmittedScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerAuthPage(
      maxWidth: 560,
      child: OrganizerCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: FairTixMark(width: 44),
            ),
            const SizedBox(height: 14),
            Text(
              'One more step',
              style: orgText(
                p,
                size: 28,
                weight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account was created, but we couldn’t finish uploading '
              'your verification documents. Upload them now so an admin can '
              'review your application.',
              style: orgText(p, size: 13.5, color: p.textSecondary),
            ),
            const SizedBox(height: 22),
            if (_needsVenueProof) ...[
              const OrganizerFieldLabel('Government or school ID'),
              const SizedBox(height: 7.5),
              OrganizerUploadBox(
                title: 'Upload ID',
                hint: 'JPG or PNG',
                fileName: _venueProofFileName,
                onTap: () => _pickDocument(isVenueProof: true),
              ),
              const SizedBox(height: 16),
            ],
            if (_needsPermit) ...[
              const OrganizerFieldLabel('Proof of organization'),
              const SizedBox(height: 7.5),
              OrganizerUploadBox(
                title: 'Upload document',
                hint: 'Org certificate, DTI registration or business permit',
                fileName: _permitFileName,
                onTap: () => _pickDocument(isVenueProof: false),
              ),
              const SizedBox(height: 16),
            ],
            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: orgText(
                  p,
                  size: 13,
                  weight: FontWeight.w600,
                  color: p.danger,
                ),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 6),
            OrganizerPrimaryButton(
              label: 'Submit Documents',
              loading: _isSubmitting,
              onPressed: _canSubmit ? _handleSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}
