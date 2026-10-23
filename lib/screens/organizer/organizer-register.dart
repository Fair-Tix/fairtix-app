import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/organizer_auth_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-login.dart';
import 'organizer-otp-verification.dart';

/// "Apply as an organizer" (Mahilum design): one wide card with the mark, a
/// 2-column form, two document drop zones and the submit button.
///
/// Notes on the redesign:
///  * The design has no "Confirm password" field, so it was removed.
///  * The two upload boxes are labelled "Government or school ID" and "Proof
///    of organization" as in the design. They still use the existing storage
///    slots (`venue_proof` and `event_permit`) so the backend is unchanged.
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String? _errorText;

  // Slot 1: government / school ID (stored as `venue_proof`).
  Uint8List? _venueProofBytes;
  String? _venueProofFileName;
  String? _venueProofExt;

  // Slot 2: proof of organization (stored as `event_permit`).
  Uint8List? _permitBytes;
  String? _permitFileName;
  String? _permitExt;

  @override
  void dispose() {
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_venueProofBytes == null || _permitBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload both verification documents before submitting.',
          ),
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

    // Email verification comes before the application counts as submitted.
    // Supabase has Confirm email enabled, so signUp() returns no session yet
    // and Storage RLS would reject the document uploads. The OTP screen holds
    // the picked files, verifies the code (which creates the session),
    // uploads both documents, then continues to the Application Submitted
    // screen.
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerOtpVerificationScreen(
          email: _emailController.text.trim().toLowerCase(),
          venueProofBytes: _venueProofBytes!,
          venueProofExt: _venueProofExt ?? 'pdf',
          permitBytes: _permitBytes!,
          permitExt: _permitExt ?? 'pdf',
        ),
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);

    return OrganizerAuthPage(
      maxWidth: 760,
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      child: OrganizerCard(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 560;

              Widget pair(Widget a, Widget b) {
                if (!twoColumns) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [a, const SizedBox(height: 16), b],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 16),
                    Expanded(child: b),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FairTixMark(width: 44),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Apply as an organizer',
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
                    'An admin reviews every application before you can '
                    'create events.',
                    style: orgText(p, size: 13.5, color: p.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  pair(
                    OrganizerLabeledField(
                      label: 'Organization name',
                      hint: 'Your organization',
                      controller: _organizationNameController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Organization name is required'
                          : null,
                    ),
                    OrganizerLabeledField(
                      label: 'Full name',
                      hint: 'As shown on your ID',
                      controller: _fullNameController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full name is required'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  pair(
                    OrganizerLabeledField(
                      label: 'Email',
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
                    OrganizerLabeledField(
                      label: 'Password',
                      hint: 'At least 8 characters',
                      controller: _passwordController,
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) return 'Use at least 8 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  pair(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OrganizerFieldLabel('Government or school ID'),
                        const SizedBox(height: 7.5),
                        OrganizerUploadBox(
                          title: 'Upload ID',
                          hint: 'JPG or PNG',
                          fileName: _venueProofFileName,
                          onTap: () => _pickDocument(isVenueProof: true),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OrganizerFieldLabel('Proof of organization'),
                        const SizedBox(height: 7.5),
                        OrganizerUploadBox(
                          title: 'Upload document',
                          hint:
                              'Org certificate, DTI registration or business permit',
                          fileName: _permitFileName,
                          onTap: () => _pickDocument(isVenueProof: false),
                        ),
                      ],
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorText!,
                      style: orgText(
                        p,
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  OrganizerPrimaryButton(
                    label: 'Submit Application',
                    loading: _isSubmitting,
                    onPressed: _handleSubmit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: orgText(
                            p,
                            size: 13,
                            height: 1.3,
                            color: p.textSecondary,
                          ),
                        ),
                        OrganizerTextLink(label: 'Log in', onTap: _goToLogin),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
