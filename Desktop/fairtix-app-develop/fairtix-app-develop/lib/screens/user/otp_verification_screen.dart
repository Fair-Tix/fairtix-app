import 'package:flutter/material.dart';

import '../../services/user_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/otp_box_input.dart';
import '../../widgets/pill_button.dart';
import 'identity_verification_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _code = '';
  bool _isVerifying = false;
  bool _isResending = false;

  Future<void> _handleVerify() async {
    setState(() => _isVerifying = true);
    try {
      await UserAuthService.instance.verifyRegistrationOtp(
        email: widget.email,
        token: _code,
      );
    } on UserAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isVerifying = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()),
    );
  }

  Future<void> _handleResend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await UserAuthService.instance.resendRegistrationOtp(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.')),
      );
    } on UserAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayEmail = widget.email.isNotEmpty ? widget.email : 'your email';
    return Scaffold(
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.subtleWhite, width: 1.5),
                ),
                child: const Icon(Icons.mail_outline, color: AppColors.white, size: 30),
              ),
              const SizedBox(height: 28),
              Text('Verify Your Email', style: AppTextStyles.heading, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to\n$displayEmail',
                textAlign: TextAlign.center,
                style: AppTextStyles.tagline,
              ),
              const SizedBox(height: 32),
              OtpBoxInput(length: 6, onChanged: (value) => setState(() => _code = value)),
              const SizedBox(height: 32),
              PillButton(
                label: 'Verify',
                loading: _isVerifying,
                onPressed: _code.length == 6 ? _handleVerify : null,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _isResending ? null : _handleResend,
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.tagline,
                    children: [
                      const TextSpan(text: "Didn't receive a code? "),
                      TextSpan(
                        text: _isResending ? 'Sending...' : 'Resend',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
