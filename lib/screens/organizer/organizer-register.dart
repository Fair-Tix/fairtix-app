import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'app_colors.dart';
import '../../services/organizer_auth_service.dart';
import 'organizer-application-submitted.dart';

class OrganizerRegisterScreen extends StatefulWidget {
  const OrganizerRegisterScreen({super.key});

  @override
  State<OrganizerRegisterScreen> createState() =>
      _OrganizerRegisterScreenState();
}

class _OrganizerRegisterScreenState extends State<OrganizerRegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _organizationNameController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String? _errorText;

  Uint8List? _venueProofBytes;
  String? _venueProofFileName;
  String? _venueProofExt;

  Uint8List? _permitBytes;
  String? _permitFileName;
  String? _permitExt;

  @override
  void dispose() {
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({required bool isVenueProof}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // forces bytes to load into memory on every platform, incl. web
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

  Future<void> _handleSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_venueProofBytes == null || _permitBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please upload both verification documents before submitting.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await OrganizerAuthService.instance.register(
        fullName: _fullNameController.text,
        organizationName: _organizationNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on OrganizerAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
      return;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    // Supabase only hands back an active session immediately on signUp()
    // when "Confirm email" is disabled for the project. With
    // confirmations enabled (the current setup — see
    // docs/FairTix-Backend-Roadmap.md), there's no session yet at this
    // point, and Storage RLS requires one, so the documents can't be
    // uploaded until the organizer confirms their email and logs in
    // (not built yet — tracked as a known gap in the roadmap). Uploading
    // opportunistically here means this keeps working the moment that
    // changes, without another code change.
    if (OrganizerAuthService.instance.hasActiveSession) {
      try {
        await OrganizerAuthService.instance.uploadOrganizerDocument(
          docKind: 'venue_proof',
          bytes: _venueProofBytes!,
          fileExtension: _venueProofExt ?? 'pdf',
        );
        await OrganizerAuthService.instance.uploadOrganizerDocument(
          docKind: 'event_permit',
          bytes: _permitBytes!,
          fileExtension: _permitExt ?? 'pdf',
        );
      } on OrganizerAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Your account was created, but document upload failed: ${e.message}')),
        );
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganizerApplicationSubmittedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isWide)
            Expanded(
              flex: 5,
              child: AuthSidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FairTixLogo(fontSize: 22),
                    const SizedBox(height: 6),
                    Text(
                      'Start selling tickets in minutes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),
                    _featureCheck('Verified organizer badge'),
                    const SizedBox(height: 16),
                    _featureCheck('Real-time analytics dashboard'),
                    const SizedBox(height: 16),
                    _featureCheck('Instant payout system'),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Register as Organizer',
                        style: AppTextStyles.h1,
                      ),
                      const SizedBox(height: 28),
                      _validatedField(
                        label: 'Organization Name',
                        hint: 'e.g. UC Main Student Council',
                        controller: _organizationNameController,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Organization name is required'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _validatedField(
                              label: 'Full Name',
                              hint: 'e.g. Juan Dela Cruz',
                              controller: _fullNameController,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Full name is required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _validatedField(
                              label: 'Email Address',
                              hint: 'you@organization.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _validatedField(
                              label: 'Password',
                              hint: '••••••••',
                              obscureText: true,
                              controller: _passwordController,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 8) {
                                  return 'Use at least 8 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _validatedField(
                              label: 'Confirm Password',
                              hint: '••••••••',
                              obscureText: true,
                              controller: _confirmPasswordController,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Verification Documents',
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _uploadBox(
                              label: _venueProofFileName ??
                                  'Proof of Venue Booking',
                              uploaded: _venueProofBytes != null,
                              onTap: () => _pickDocument(isVenueProof: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _uploadBox(
                              label: _permitFileName ?? 'Valid Event Permit',
                              uploaded: _permitBytes != null,
                              onTap: () => _pickDocument(isVenueProof: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
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
                              label: 'Submit Application',
                              color: AppColors.primaryPurpleDarker,
                              onPressed: _handleSubmit,
                            ),
                      const SizedBox(height: 16),
                    ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _validatedField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyGray,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryPurple),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureCheck(String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 14, color: AppColors.primaryPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.4),
            width: 1.4,
            style: BorderStyle.solid,
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
              size: 26,
            ),
            const SizedBox(height: 8),
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