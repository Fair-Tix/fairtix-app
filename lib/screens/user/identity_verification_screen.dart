import 'package:flutter/material.dart';

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
  String? _uploadedFileName;
  String _idType = 'Philippine National ID (PhilSys)';

  static const _idTypes = [
    'Philippine National ID (PhilSys)',
    "Driver's License",
    'Passport',
    'UMID',
    'School ID',
  ];

  Future<void> _pickId() async {
    // TODO: hook up image_picker / file_picker to select or capture the ID photo.
    setState(() => _uploadedFileName = 'id_photo.jpg');
  }

  void _handleSubmit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SelfieVerificationScreen()),
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
                DashedUploadBox(onTap: _pickId, fileName: _uploadedFileName),
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
                  onPressed: _uploadedFileName != null ? _handleSubmit : null,
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
