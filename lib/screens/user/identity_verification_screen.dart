import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../navigation/main_shell.dart';
import '../../services/user_auth_service.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_identity_ui.dart';
import '../../widgets/ft_otp_field.dart';
import '../../widgets/ft_registration_ui.dart';
import 'selfie_verification_screen.dart';

/// Registration, Step 3 of 5: upload a photo of the ID.
///
/// Dark redesign. The picking, uploading and navigation logic is the same as
/// before; only how it looks changed (see the notes on [_saveForLater] and
/// [_pillLabel] for the two small additions).
class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _fileBytes;
  String? _fileExtension;
  String? _uploadedFileName;
  String _idType = 'Philippine National ID (PhilSys)';
  bool _isSubmitting = false;
  String? _errorText;

  static const _idTypes = [
    'Philippine National ID (PhilSys)',
    "Driver's License",
    'Passport',
    'UMID',
    'School ID',
  ];

  /// Display text for a pill. The stored value (what is saved and passed on)
  /// is always the full string in [_idTypes]; only the long one is shortened
  /// so it sits well in a pill.
  String _pillLabel(String type) =>
      type == 'Philippine National ID (PhilSys)' ? 'PhilSys ID' : type;

  /// Shows a Camera/Gallery chooser, then reads the picked image into
  /// memory as bytes so the same code path works on mobile and web
  /// (no `dart:io File`, which isn't available on web).
  Future<void> _pickId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: FtColors.otpFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FtColors.otpBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: FtColors.otpActive),
              title: Text('Take a photo', style: FtText.input().copyWith(fontSize: 15.5)),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: FtColors.otpActive),
              title: Text('Choose from gallery', style: FtText.input().copyWith(fontSize: 15.5)),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not open the camera/gallery. Please check app permissions.');
      return;
    }
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final name = picked.name;
    final ext = name.contains('.') ? name.split('.').last : 'jpg';

    if (!mounted) return;
    setState(() {
      _fileBytes = bytes;
      _fileExtension = ext;
      _uploadedFileName = name;
      _errorText = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (_fileBytes == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await UserAuthService.instance.uploadIdentityDocument(
        idType: _idType,
        bytes: _fileBytes!,
        fileExtension: _fileExtension ?? 'jpg',
      );
    } on UserAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).push(
      ftSlideFadeRoute(SelfieVerificationScreen(idType: _idType)),
    );
  }

  /// "Save and finish later": the email is already verified, so the account
  /// exists and signed in. Open the app; buying and reselling stay locked
  /// until an ID is submitted and approved, and the app offers to submit it
  /// when they try (see services/access_control.dart).
  Future<void> _saveForLater() async {
    if (_isSubmitting) return;
    final account = await UserAuthService.instance.refreshAccount();
    if (!mounted) return;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We couldn’t reach FairTix. Check your connection and try again.'),
        ),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      ftFadeRoute(const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FtRegistrationScaffold(
      step: 3,
      entrance: true,
      title: 'Verify your ID',
      subtitle:
          'Every ticket is tied to a real person, so scalpers can’t bulk-buy and your tickets stay yours.',
      subtitleColor: FtColors.otpSecondary,
      onBack: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
      headerExtra: const FtProgressCard(
        title: 'You’re almost there',
        subtitle: 'About 2 minutes left',
        labels: ['Account', 'Email', 'ID', 'Selfie', 'Done'],
        completed: 2, // Account and Email are done; ID is the current step.
      ),
      body: [
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final type in _idTypes)
              FtChoicePill(
                label: _pillLabel(type),
                selected: type == _idType,
                onTap: () => setState(() => _idType = type),
              ),
          ],
        ),
        const SizedBox(height: 28),
        FtUploadBox(
          onTap: _isSubmitting ? () {} : _pickId,
          fileName: _uploadedFileName,
          previewBytes: _fileBytes,
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 14),
          FtBanner(message: _errorText!),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 17, color: FtColors.otpSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Encrypted, and used only to verify you.',
                style: FtText.legal().copyWith(fontSize: 13.5, color: FtColors.otpSecondary),
              ),
            ),
          ],
        ),
      ],
      button: FtVerifyButton(
        label: 'Continue',
        enabled: _fileBytes != null,
        loading: _isSubmitting,
        onPressed: _handleSubmit,
      ),
      footer: InkWell(
        onTap: _isSubmitting ? null : _saveForLater,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          child: Text(
            'Save and finish later',
            style: FtText.legal().copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FtColors.otpSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
