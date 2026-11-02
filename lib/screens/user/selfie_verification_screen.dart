import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/user_auth_service.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_otp_field.dart';
import '../../widgets/ft_registration_ui.dart';
import '../../widgets/ft_selfie_ui.dart';
import 'registration_pending_screen.dart';

/// Registration, Step 4 of 5: take a live selfie.
///
/// Dark redesign. Capture, retake, upload and navigation logic is unchanged;
/// only the presentation was replaced.
class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key, this.idType = ''});

  final String idType;

  @override
  State<SelfieVerificationScreen> createState() => _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selfieBytes;
  String? _selfieExtension;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  String? _errorText;

  /// Opens the front camera directly (no gallery option — this step is
  /// meant to capture a live selfie, not let someone pick an old photo).
  Future<void> _handleCapture() async {
    setState(() {
      _isCapturing = true;
      _errorText = null;
    });

    XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        imageQuality: 90,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorText = 'Could not open the camera. Please check app permissions.';
      });
      return;
    }

    if (shot == null) {
      // User backed out of the camera without taking a photo.
      if (!mounted) return;
      setState(() => _isCapturing = false);
      return;
    }

    final bytes = await shot.readAsBytes();
    final name = shot.name;
    final ext = name.contains('.') ? name.split('.').last : 'jpg';

    if (!mounted) return;
    setState(() {
      _selfieBytes = bytes;
      _selfieExtension = ext;
      _isCapturing = false;
    });
  }

  void _handleRetake() {
    setState(() {
      _selfieBytes = null;
      _selfieExtension = null;
      _errorText = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (_selfieBytes == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await UserAuthService.instance.uploadSelfie(
        bytes: _selfieBytes!,
        fileExtension: _selfieExtension ?? 'jpg',
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
      ftSlideFadeRoute(
        RegistrationPendingScreen(
          idType: widget.idType,
          submittedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelfie = _selfieBytes != null;
    final busy = _isCapturing || _isSubmitting;
    final t = FtAuthTheme.live(context);

    return FtRegistrationScaffold(
      followTheme: true,
      step: 4,
      entrance: true,
      title: 'Take a quick selfie',
      subtitle: 'We’ll compare it with the photo on your ID.',
      subtitleColor: t.secondaryText,
      onBack: busy ? null : () => Navigator.of(context).maybePop(),
      body: [
        FtSelfieFrame(
          selfieBytes: _selfieBytes,
          caption: hasSelfie
              ? 'Looking good! Submit or retake.'
              : 'Position your face in the oval',
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 14),
          FtBanner(message: _errorText!),
        ],
        const SizedBox(height: 22),
        const FtTipsRow(tips: ['Good lighting', 'Face the camera', 'No glasses']),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 17, color: t.secondaryText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Encrypted, and used only to verify you.',
                style: FtText.legal().copyWith(fontSize: 13.5, color: t.secondaryText),
              ),
            ),
          ],
        ),
      ],
      button: FtVerifyButton(
        label: hasSelfie ? 'Use This Selfie' : 'Take Selfie',
        loading: hasSelfie ? _isSubmitting : _isCapturing,
        onPressed: hasSelfie ? _handleSubmit : _handleCapture,
      ),
      footer: (hasSelfie && !_isSubmitting)
          ? InkWell(
              onTap: _handleRetake,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                child: Text(
                  'Retake Photo',
                  style: FtText.legal().copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.secondaryText,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
