import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/user_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashed_upload_box.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/light_pill_field.dart';
import '../../widgets/purple_header_bar.dart';
import '../../widgets/step_dots.dart';
import 'selfie_verification_screen.dart';

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

  /// Shows a Camera/Gallery chooser, then reads the picked image into
  /// memory as bytes so the same code path works on mobile and web
  /// (no `dart:io File`, which isn't available on web).
  Future<void> _pickId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accentPurple),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accentPurple),
              title: const Text('Choose from gallery'),
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
      MaterialPageRoute(
        builder: (_) => SelfieVerificationScreen(idType: _idType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: PurpleHeaderBar(
        title: 'Verify Identity',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Verify Your Identity', style: AppTextStyles.sectionHeading, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Upload a valid government or school ID to activate your account',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 18),
                const StepDots(totalSteps: 3, currentStep: 1),
                const SizedBox(height: 24),
                DashedUploadBox(
                  onTap: _isSubmitting ? () {} : _pickId,
                  fileName: _uploadedFileName,
                  previewBytes: _fileBytes,
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ID TYPE', style: AppTextStyles.cardLabel),
                ),
                const SizedBox(height: 8),
                LightPillDropdown<String>(
                  value: _idType,
                  items: _idTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _idType = v ?? _idType),
                ),
                const SizedBox(height: 24),
                GradientPillButton(
                  label: 'Submit for Verification',
                  loading: _isSubmitting,
                  onPressed: _fileBytes != null ? _handleSubmit : null,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text('Your information is encrypted and secure', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
