import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/organizer_auth_service.dart';
import 'app_colors.dart';
import 'organizer-application-submitted.dart';

/// Email verification step of organizer registration. Mirrors the eventgoer's
/// `OtpVerificationScreen`: Supabase emails a 6-digit code (Confirm signup
/// template, `{{ .Token }}`) and the organizer must enter it before the
/// application is considered submitted.
///
/// Verifying the code also creates a Supabase session, which is what lets the
/// two verification documents be uploaded here (Storage RLS needs a signed-in
/// user). If an upload fails, the organizer is still routed on and
/// `OrganizerLoginScreen`'s `hasSubmittedDocuments` check sends them to
/// `OrganizerDocumentUploadScreen` at next login as a backstop.
class OrganizerOtpVerificationScreen extends StatefulWidget {
  const OrganizerOtpVerificationScreen({
    super.key,
    required this.email,
    required this.venueProofBytes,
    required this.venueProofExt,
    required this.permitBytes,
    required this.permitExt,
  });

  final String email;
  final Uint8List venueProofBytes;
  final String venueProofExt;
  final Uint8List permitBytes;
  final String permitExt;

  @override
  State<OrganizerOtpVerificationScreen> createState() =>
      _OrganizerOtpVerificationScreenState();
}

class _OrganizerOtpVerificationScreenState
    extends State<OrganizerOtpVerificationScreen> {
  static const int _codeLength = 6;
  // Supabase rate-limits confirmation emails, so don't let Resend be spammed.
  static const int _resendCooldownSeconds = 60;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  Timer? _cooldownTimer;
  int _cooldownRemaining = _resendCooldownSeconds; // a code was just sent

  @override
  void initState() {
    super.initState();
    _beginCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownRemaining = _resendCooldownSeconds);
    _beginCooldownTimer();
  }

  void _beginCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownRemaining--);
      if (_cooldownRemaining <= 0) timer.cancel();
    });
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    final code = _codeController.text.trim();
    if (code.length != _codeLength) {
      setState(() => _errorText = 'Enter the $_codeLength-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await OrganizerAuthService.instance.verifyRegistrationOtp(
        email: widget.email,
        token: code,
      );
    } on OrganizerAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = e.message;
      });
      return;
    }

    // Email confirmed and a session now exists, so the documents can finally
    // be uploaded.
    String? uploadWarning;
    try {
      await OrganizerAuthService.instance.uploadOrganizerDocument(
        docKind: 'venue_proof',
        bytes: widget.venueProofBytes,
        fileExtension: widget.venueProofExt,
      );
      await OrganizerAuthService.instance.uploadOrganizerDocument(
        docKind: 'event_permit',
        bytes: widget.permitBytes,
        fileExtension: widget.permitExt,
      );
    } on OrganizerAuthException catch (e) {
      uploadWarning =
          'Your email is verified, but document upload failed: ${e.message} '
          'You can upload them again after logging in.';
    }

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (uploadWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uploadWarning)),
      );
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const OrganizerApplicationSubmittedScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _handleResend() async {
    if (_isResending || _cooldownRemaining > 0) return;
    setState(() {
      _isResending = true;
      _errorText = null;
    });
    try {
      await OrganizerAuthService.instance.resendRegistrationOtp(
        email: widget.email,
      );
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.')),
      );
    } on OrganizerAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final displayEmail = widget.email.isNotEmpty ? widget.email : 'your email';
    final canResend = !_isResending && _cooldownRemaining <= 0;

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
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.mail_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'One quick step',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verify your email so we know it\'s really you before '
                      'we review your organizer application.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F0FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.mail_outline,
                                color: AppColors.primaryPurple,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Verify Your Email',
                            style: AppTextStyles.h1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We sent a $_codeLength-digit code to\n$displayEmail',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyGray.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 28),
                          // A single field (rather than six boxes) so pasting
                          // the whole code from the email works on web.
                          TextField(
                            controller: _codeController,
                            focusNode: _codeFocus,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: _codeLength,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() => _errorText = null),
                            onSubmitted: (_) => _handleVerify(),
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 12,
                              color: AppColors.textDark,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••••',
                              hintStyle: const TextStyle(
                                fontSize: 28,
                                letterSpacing: 12,
                                color: AppColors.borderLight,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.borderLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryPurple, width: 1.6),
                              ),
                            ),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.dangerRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _isVerifying
                              ? const SizedBox(
                                  height: 52,
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    ),
                                  ),
                                )
                              : PrimaryButton(
                                  label: 'Verify',
                                  color: AppColors.primaryPurpleDarker,
                                  onPressed: _handleVerify,
                                ),
                          const SizedBox(height: 18),
                          Center(
                            child: GestureDetector(
                              onTap: canResend ? _handleResend : null,
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodyGray,
                                  children: [
                                    const TextSpan(
                                        text: "Didn't receive a code? "),
                                    TextSpan(
                                      text: _isResending
                                          ? 'Sending...'
                                          : _cooldownRemaining > 0
                                              ? 'Resend in ${_cooldownRemaining}s'
                                              : 'Resend',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: canResend
                                            ? AppColors.primaryPurple
                                            : AppColors.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textDark, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
