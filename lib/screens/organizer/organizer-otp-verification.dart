import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/organizer_auth_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/organizer_ui.dart';
import 'organizer-application-submitted.dart';

/// Email verification step of organizer registration (Mahilum design: "Check
/// your email" card with six code boxes and a "Verify Email" button).
///
/// Supabase emails a 6-digit code (Confirm signup template, `{{ .Token }}`)
/// and the organizer must enter it before the application is considered
/// submitted. Verifying the code also creates a Supabase session, which is
/// what lets the two verification documents be uploaded here (Storage RLS
/// needs a signed-in user). If an upload fails, the organizer is still routed
/// on and `OrganizerLoginScreen`'s `hasSubmittedDocuments` check sends them to
/// `OrganizerDocumentUploadScreen` at next login as a backstop.
///
/// The six boxes are only a display: one invisible text field sits on top and
/// receives all typing, so pasting the whole code from the email works.
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
    _codeController.addListener(() => setState(() {}));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(uploadWarning)));
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

  /// 42 -> "0:42", 60 -> "1:00".
  String get _cooldownLabel {
    final s = _cooldownRemaining.clamp(0, 5999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final displayEmail = widget.email.isNotEmpty ? widget.email : 'your email';
    final canResend = !_isResending && _cooldownRemaining <= 0;

    return OrganizerAuthPage(
      maxWidth: 520,
      onBack: () => Navigator.of(context).maybePop(),
      child: OrganizerCard(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Check your email',
              textAlign: TextAlign.center,
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
              'We sent a $_codeLength-digit code to $displayEmail.',
              textAlign: TextAlign.center,
              style: orgText(p, size: 14, color: p.textSecondary),
            ),
            const SizedBox(height: 24),
            _CodeBoxes(
              controller: _codeController,
              focusNode: _codeFocus,
              length: _codeLength,
              onSubmitted: _handleVerify,
              onEdited: () {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: orgText(
                  p,
                  size: 13,
                  weight: FontWeight.w600,
                  color: p.danger,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: canResend ? _handleResend : null,
                child: Text.rich(
                  TextSpan(
                    style: orgText(
                      p,
                      size: 13,
                      height: 1.3,
                      color: p.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Didn\u2019t get it? '),
                      TextSpan(
                        text: _isResending
                            ? 'Sending...'
                            : _cooldownRemaining > 0
                            ? 'Resend in $_cooldownLabel'
                            : 'Resend',
                        style: orgText(
                          p,
                          size: 13,
                          height: 1.3,
                          weight: FontWeight.w700,
                          color: canResend ? p.accentLabel : p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OrganizerPrimaryButton(
              label: 'Verify Email',
              loading: _isVerifying,
              onPressed: _handleVerify,
            ),
          ],
        ),
      ),
    );
  }
}

/// Six display boxes with one invisible [TextField] stacked on top.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onSubmitted,
    required this.onEdited,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final VoidCallback onSubmitted;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final code = controller.text;

    return SizedBox(
      height: 61,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: AnimatedBuilder(
                    animation: focusNode,
                    builder: (context, _) {
                      final isNext = focusNode.hasFocus &&
                          (i == code.length ||
                              (i == length - 1 && code.length == length));
                      return Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isNext ? p.accentLabel : p.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: orgText(
                            p,
                            size: 24,
                            weight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          // The real input: invisible, but it still takes taps and typing.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onEdited(),
                onSubmitted: (_) => onSubmitted(),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
