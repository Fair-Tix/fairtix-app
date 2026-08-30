import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import '../../services/organizer_auth_service.dart';
import '../../services/organizer_session.dart';
import 'app_colors.dart';
import 'organizer-verification-pending.dart';

/// Shown right after an organizer's first successful login if their
/// proof-of-organization documents never made it to Storage at
/// registration time.
///
/// Why this screen exists: `organizer-register.dart`'s "Submit
/// Application" tries to upload the two documents immediately, but that
/// only works if Supabase already handed back an active session from
/// `signUp()` — which it doesn't when "Confirm email" is required (the
/// current project setup, since the eventgoer flow needs it for the OTP
/// screen). So registration succeeds, but the documents are silently
/// skipped. This screen is the backstop: [OrganizerLoginScreen] checks
/// `OrganizerAccount.hasSubmittedDocuments` after login and routes here
/// if either file is still missing, using the now-real session to
/// actually upload them via [OrganizerAuthService.uploadOrganizerDocument].
class OrganizerDocumentUploadScreen extends StatefulWidget {
  const OrganizerDocumentUploadScreen({super.key, required this.account});

  final OrganizerAccount account;

  @override
  State<OrganizerDocumentUploadScreen> createState() =>
      _OrganizerDocumentUploadScreenState();
}

class _OrganizerDocumentUploadScreenState
    extends State<OrganizerDocumentUploadScreen> {
  Uint8List? _venueProofBytes;
  String? _venueProofFileName;
  String? _venueProofExt;

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
        const SnackBar(content: Text('Could not read that file. Please try another one.')),
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
        final path = await OrganizerAuthService.instance.uploadOrganizerDocument(
          docKind: 'venue_proof',
          bytes: _venueProofBytes!,
          fileExtension: _venueProofExt ?? 'pdf',
        );
        updated = updated.copyWith(venueProofUrl: path);
      }
      if (_needsPermit && _permitBytes != null) {
        final path = await OrganizerAuthService.instance.uploadOrganizerDocument(
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
      MaterialPageRoute(builder: (_) => const OrganizerVerificationPendingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.upload_file_outlined,
                      color: AppColors.primaryPurple,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('One More Step', style: AppTextStyles.h1),
                  const SizedBox(height: 10),
                  const Text(
                    'Your account was created, but we couldn\u2019t finish uploading '
                    'your verification documents earlier. Please upload them now '
                    'so our team can review your application.',
                    style: AppTextStyles.bodyGray,
                  ),
                  const SizedBox(height: 24),
                  if (_needsVenueProof) ...[
                    _uploadBox(
                      label: _venueProofFileName ?? 'Proof of Venue Booking',
                      uploaded: _venueProofBytes != null,
                      onTap: () => _pickDocument(isVenueProof: true),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_needsPermit) ...[
                    _uploadBox(
                      label: _permitFileName ?? 'Valid Event Permit',
                      uploaded: _permitBytes != null,
                      onTap: () => _pickDocument(isVenueProof: false),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_errorText != null) ...[
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: AppColors.dangerRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _isSubmitting
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      : PrimaryButton(
                          label: 'Submit Documents',
                          onPressed: _canSubmit ? _handleSubmit : null,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadBox({
    required String label,
    required VoidCallback onTap,
    bool uploaded = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              uploaded ? Icons.check_circle : Icons.upload_file_outlined,
              color: AppColors.primaryPurple,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
