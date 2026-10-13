import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/user_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/step_dots.dart';
import 'registration_pending_screen.dart';

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
      MaterialPageRoute(
        builder: (_) => RegistrationPendingScreen(
          idType: widget.idType,
          submittedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelfie = _selfieBytes != null;
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Verify Your Identity',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const StepDots(
              totalSteps: 3,
              currentStep: 2,
              activeColor: AppColors.white,
              inactiveColor: AppColors.faintWhite,
            ),
            const Spacer(flex: 2),
            Container(
              width: 240,
              height: 240,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 3),
              ),
              child: hasSelfie
                  ? Image.memory(_selfieBytes!, fit: BoxFit.cover)
                  : const Padding(
                      padding: EdgeInsets.all(30),
                      child: Icon(Icons.person_outline, size: 130, color: AppColors.faintWhite),
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              hasSelfie ? 'Looking good! Submit or retake.' : 'Position your face within the frame',
              style: AppTextStyles.tagline,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ),
            ],
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  GradientPillButton(
                    label: hasSelfie ? 'Use This Selfie' : 'Take Selfie',
                    loading: hasSelfie ? _isSubmitting : _isCapturing,
                    onPressed: hasSelfie ? _handleSubmit : _handleCapture,
                  ),
                  const SizedBox(height: 10),
                  if (hasSelfie && !_isSubmitting)
                    GestureDetector(
                      onTap: _handleRetake,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Retake Photo',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white),
                        ),
                      ),
                    )
                  else
                    const Text(
                      'This will be compared with your uploaded ID.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.footerText,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
