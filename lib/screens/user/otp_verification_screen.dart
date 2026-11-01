import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/user_auth_service.dart';
import '../../theme/page_transitions.dart';
import '../../widgets/ft_dark_ui.dart';
import '../../widgets/ft_otp_field.dart';
import '../../widgets/ft_registration_ui.dart';
import 'identity_verification_screen.dart';

/// Registration, Step 2 of 5: confirm the email with the 6-digit code.
///
/// The code is created, emailed, hashed, expired and rate-limited by Supabase
/// Auth (the `signUp` call in Step 1 sent the first one). This screen only
/// collects it and asks Supabase to check it, so nothing is verified on the
/// device and no code is ever stored or logged here.
///
/// Two separate timers run here:
///  * a 60 second "Resend" cooldown, and
///  * a 5 minute code lifetime (see the note on [_codeLifetime]).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const int _resendCooldownSeconds = 60;

  /// How long a code is treated as valid on screen. Supabase decides the real
  /// lifetime: set Authentication > Providers > Email > "Email OTP Expiration"
  /// to 300 seconds so the server enforces the same 5 minutes.
  static const Duration _codeLifetime = Duration(minutes: 5);

  static const String _offlineMessage =
      'We couldn’t reach FairTix. Check your connection and try again.';
  static const String _incorrectMessage =
      'That code is incorrect or has expired. Check your email and try again.';
  static const String _expiredMessage =
      'This code has expired. Tap Resend Code to get a new one.';

  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  Timer? _ticker;
  late DateTime _resendAvailableAt;
  late DateTime _codeExpiresAt;
  int _secondsLeft = _resendCooldownSeconds;
  bool _codeExpired = false;

  bool _verifying = false;
  bool _resending = false;
  bool _success = false;
  bool _hasError = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _startTimers(); // the first code was emailed when Step 1 was submitted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- Timers ---------------------------------------------------------------

  void _startTimers({int cooldownSeconds = _resendCooldownSeconds}) {
    final now = DateTime.now();
    _resendAvailableAt = now.add(Duration(seconds: cooldownSeconds));
    _codeExpiresAt = now.add(_codeLifetime);
    _secondsLeft = cooldownSeconds;
    _codeExpired = false;
    _ticker?.cancel();
    // Compared against the clock (not counted), so it stays right after the
    // app has been in the background.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final left = math.max(
      0,
      (_resendAvailableAt.difference(now).inMilliseconds / 1000).ceil(),
    );
    final expired = !now.isBefore(_codeExpiresAt);
    if (left != _secondsLeft || expired != _codeExpired) {
      setState(() {
        _secondsLeft = left;
        if (expired && !_codeExpired) {
          _codeExpired = true;
          _hasError = false;
          _notice = null;
          _error = _expiredMessage;
        }
      });
    }
    if (left == 0 && expired) _ticker?.cancel();
  }

  // --- Helpers --------------------------------------------------------------

  /// f•••••••••••@gmail.com: first letter, then dots, then the domain.
  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final dots = (at - 1).clamp(3, 11);
    return '${email[0]}${'•' * dots}${email.substring(at)}';
  }

  String _countdownLabel(int seconds) =>
      '0:${seconds.toString().padLeft(2, '0')}';

  bool _looksOffline(String m) =>
      m.contains('socket') ||
      m.contains('failed host lookup') ||
      m.contains('clientexception') ||
      m.contains('network') ||
      m.contains('timed out');

  bool _looksRateLimited(String m) =>
      m.contains('too many') ||
      m.contains('rate limit') ||
      m.contains('only request this after');

  // --- Verify ---------------------------------------------------------------

  void _onCodeChanged(String value) {
    if (_error != null || _hasError || _notice != null) {
      setState(() {
        _error = null;
        _hasError = false;
        _notice = null;
      });
    } else {
      setState(() {}); // refresh the button state
    }
    if (value.length == FtOtpField.length) _verify();
  }

  Future<void> _verify() async {
    if (_verifying || _success || _resending) return;
    final code = _codeController.text;
    if (code.length != FtOtpField.length) return;

    if (_codeExpired) {
      setState(() => _error = _expiredMessage);
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
      _notice = null;
      _hasError = false;
    });

    try {
      await UserAuthService.instance.verifyRegistrationOtp(
        email: widget.email,
        token: code,
      );
    } on UserAuthException catch (e) {
      final m = e.message.toLowerCase();
      if (_looksRateLimited(m)) {
        _failQuietly('Too many attempts. Please wait a moment and try again.');
      } else if (_looksOffline(m)) {
        _failQuietly(_offlineMessage);
      } else {
        // Supabase answers "expired or invalid" for both, so the message
        // covers both.
        await _failIncorrect();
      }
      return;
    } catch (_) {
      _failQuietly(_offlineMessage);
      return;
    }
    if (!mounted) return;

    // Verified: the server has confirmed the email and opened a session.
    HapticFeedback.lightImpact();
    setState(() {
      _verifying = false;
      _success = true;
    });
    final reduce = MediaQuery.disableAnimationsOf(context);
    await Future<void>.delayed(Duration(milliseconds: reduce ? 150 : 900));
    if (!mounted) return;
    // Replace (not push): going "back" into an already-verified code screen
    // would be a dead end.
    Navigator.of(context).pushReplacement(
      ftSlideFadeRoute(const IdentityVerificationScreen()),
    );
  }

  /// Network / rate-limit problems: show the message, keep the digits.
  void _failQuietly(String message) {
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _error = message;
    });
  }

  /// Wrong or expired code: red borders + shake, then clear and refocus.
  Future<void> _failIncorrect() async {
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _hasError = true;
      _error = _incorrectMessage;
    });
    HapticFeedback.mediumImpact();
    if (MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } else {
      await _shake.forward(from: 0);
    }
    if (!mounted) return;
    _codeController.clear(); // digits are cleared after the error is shown
    _focusNode.requestFocus();
    setState(() {});
  }

  // --- Resend ---------------------------------------------------------------

  Future<void> _resend() async {
    if (_resending || _verifying || _success || _secondsLeft > 0) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
      _hasError = false;
    });

    try {
      await UserAuthService.instance.resendRegistrationOtp(email: widget.email);
    } on UserAuthException catch (e) {
      final m = e.message.toLowerCase();
      if (!mounted) return;
      if (_looksRateLimited(m)) {
        // "...you can only request this after 42 seconds": follow the server.
        final wait = int.tryParse(
          RegExp(r'(\d+)\s*second').firstMatch(m)?.group(1) ?? '',
        );
        setState(() {
          _resending = false;
          _error = 'Please wait a moment before requesting another code.';
          if (wait != null) {
            _resendAvailableAt = DateTime.now().add(Duration(seconds: wait));
            _secondsLeft = wait;
            _ticker?.cancel();
            _ticker = Timer.periodic(
              const Duration(seconds: 1),
              (_) => _tick(),
            );
          }
        });
      } else if (_looksOffline(m)) {
        setState(() {
          _resending = false;
          _error = _offlineMessage;
        });
      } else {
        setState(() {
          _resending = false;
          _error = 'We couldn’t send the email. Please try again in a moment.';
        });
      }
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = _offlineMessage;
      });
      return;
    }
    if (!mounted) return;

    // A new code replaces the old one on the server. Restart both timers.
    _codeController.clear();
    _startTimers();
    setState(() {
      _resending = false;
      _notice = 'A new code is on its way.';
    });
    _focusNode.requestFocus();
  }

  // --- UI -------------------------------------------------------------------

  Widget _resendLine() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final base = FtText.legal().copyWith(
      fontSize: 14,
      color: FtColors.otpSecondary,
    );
    final strong = base.copyWith(fontWeight: FontWeight.w700);

    final Widget trailing;
    if (_resending) {
      trailing = SizedBox(
        key: const ValueKey('sending'),
        width: 16,
        height: 16,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: FtColors.otpActive,
        ),
      );
    } else if (_secondsLeft > 0) {
      trailing = Text(
        'Resend in ${_countdownLabel(_secondsLeft)}',
        key: const ValueKey('countdown'),
        style: strong.copyWith(color: FtColors.otpActive.withValues(alpha: 0.8)),
      );
    } else {
      trailing = InkWell(
        key: const ValueKey('resend'),
        onTap: _resend,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Text(
            'Resend Code',
            style: strong.copyWith(color: FtColors.otpActive),
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: false,
      child: Row(
        children: [
          Text('Didn’t get it? ', style: base),
          AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
            child: trailing,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complete = _codeController.text.length == FtOtpField.length;

    return FtRegistrationScaffold(
      step: 2,
      entrance: true,
      title: 'Check your email',
      subtitle: 'We sent a 6-digit code to ${_maskEmail(widget.email)}.',
      subtitleColor: FtColors.otpSecondary,
      onBack: (_verifying || _success) ? null : () => Navigator.of(context).maybePop(),
      body: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            return Transform.translate(
              offset: Offset(math.sin(t * math.pi * 6) * 9 * (1 - t), 0),
              child: child,
            );
          },
          child: FtOtpField(
            controller: _codeController,
            focusNode: _focusNode,
            hasError: _hasError,
            readOnly: _verifying || _success,
            onChanged: _onCodeChanged,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topLeft,
          child: (_error != null || _notice != null)
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error ?? _notice!,
                      style: FtText.error().copyWith(
                        color: _error != null
                            ? FtColors.danger
                            : FtColors.otpSecondary,
                        fontWeight: _error != null
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 22),
        _resendLine(),
      ],
      button: FtVerifyButton(
        label: 'Verify Email',
        enabled: complete && !_codeExpired && !_resending,
        loading: _verifying,
        success: _success,
        onPressed: _verify,
      ),
    );
  }
}
