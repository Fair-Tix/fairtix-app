import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/organizer.dart';
import '../../services/organizer_auth_service.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/fairtix_mark.dart';
import '../../widgets/theme_mode_switch.dart';
import '../../widgets/top_glow_background.dart';
import 'organizer-document-upload.dart';
import 'organizer-register.dart';
import 'organizer-dashboard.dart';
import 'organizer-subscription-plan.dart';

/// Organizer Log In (Mahilum design): brand panel on the left, form on the
/// right. Layout values are measured from the design (1440x800 frame, Plus
/// Jakarta Sans): form column 420 wide, inputs 54 tall, button 49 tall.
class OrganizerLoginScreen extends StatefulWidget {
  const OrganizerLoginScreen({super.key});

  @override
  State<OrganizerLoginScreen> createState() => _OrganizerLoginScreenState();
}

class _OrganizerLoginScreenState extends State<OrganizerLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Login logic (unchanged)
  // ---------------------------------------------------------------------
  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    OrganizerAccount account;
    try {
      account = await OrganizerAuthService.instance.login(
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
    if (!mounted) return;

    // Route based on the account's real id_verification_status rather
    // than always going to the Dashboard:
    //  - documents missing -> "One More Step" upload screen (registration
    //    couldn't upload them earlier because no session existed yet)
    //  - not approved yet -> Dashboard, browse-only. Approval-gated features
    //    stay locked (with a banner saying why) until an admin approves.
    //  - approved, never subscribed -> pick a subscription plan first
    //  - approved, plan expired -> Dashboard; login is never blocked, only the
    //    subscription features lock until they renew
    //  - approved, has plan -> straight into the Dashboard
    if (!account.hasSubmittedDocuments) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizerDocumentUploadScreen(account: account),
        ),
        (route) => false,
      );
      return;
    }

    if (!account.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Welcome back! Your application is still under review. You can browse '
            'for now; other features unlock once an admin approves it.',
          ),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          account.subscriptionExpired
              ? 'Welcome back! Your subscription has expired. You can still view your '
                  'account; renew your plan to unlock event tools.'
              : 'Welcome back! Login successful.',
        ),
      ),
    );
    if (account.subscriptionPlan == null && !account.subscriptionExpired) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrganizerSubscriptionPlanScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
        (route) => false,
      );
    }
  }

  void _showForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset is coming soon. Please contact support.'),
      ),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerRegisterScreen()),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          Row(
            children: [
              if (isWide) Expanded(child: _BrandPanel(p: p)),
              Expanded(child: _FormPanel(state: this, p: p, showLogo: !isWide)),
            ],
          ),
          // Light / Dark switch, top-right.
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ThemeModeSwitch(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Left: brand panel
// -------------------------------------------------------------------------
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.p});

  final FairTixPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 96, right: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The logo files are trimmed to the ticket, so no offset is needed
          // to line it up with the headline.
          const FairTixMark(width: 190),
          const SizedBox(height: 28),
          Text(
            'Sell tickets that\ncan\u2019t be faked.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 18.6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Verified buyers, dynamic QR codes and capped resale, '
              'built into every event you run.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                height: 1.56,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Right: form panel
// -------------------------------------------------------------------------
class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.state,
    required this.p,
    required this.showLogo,
  });

  final _OrganizerLoginScreenState state;
  final FairTixPalette p;

  /// On narrow screens the brand panel is hidden, so show the logo above the form.
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Glow is centered on the panel's left edge, clipped to this panel.
        const TopGlowBackground(centerX: 0.03, radiusX: 660),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: state._formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showLogo) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: FairTixMark(width: 104),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Log in',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter your organizer account details.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.4,
                        color: p.textSecondary,
                      ),
                    ),
                    if (OrganizerAuthService.debugCredentialsHint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Test account: ${OrganizerAuthService.debugCredentialsHint}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18.4),
                    _FieldLabel('Email', p: p),
                    const SizedBox(height: 7.5),
                    _AuthField(
                      p: p,
                      controller: state._emailController,
                      hint: 'you@organization.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Password', p: p),
                    const SizedBox(height: 7.5),
                    _AuthField(
                      p: p,
                      controller: state._passwordController,
                      hint: '',
                      obscureText: true,
                      onSubmitted: (_) => state._handleLogin(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    if (state._errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state._errorText!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16.5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _TextLink(
                        label: 'Forgot password?',
                        color: p.accentLabel,
                        onTap: state._showForgotPassword,
                      ),
                    ),
                    const SizedBox(height: 19),
                    _SubmitButton(
                      label: 'Log In',
                      loading: state._isSubmitting,
                      onPressed: state._handleLogin,
                    ),
                    const SizedBox(height: 18.5),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.3,
                            color: p.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Want to host events? '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: _TextLink(
                                label: 'Apply as an organizer',
                                color: p.accentLabel,
                                onTap: state._goToRegister,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// Small building blocks
// -------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.p});

  final String text;
  final FairTixPalette p;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.p,
    required this.controller,
    required this.hint,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final FairTixPalette p;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?) validator;
  final ValueChanged<String>? onSubmitted;

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      height: 1.3,
      color: p.textPrimary,
    );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: textStyle,
      cursorColor: p.accentLabel,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: textStyle.copyWith(color: p.textSecondary),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: p.danger),
        filled: true,
        fillColor: p.surface,
        // 18 + 18 + 18.2 line = 54px tall, as in the design.
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _border(p.border),
        enabledBorder: _border(p.border),
        focusedBorder: _border(p.accentLabel),
        errorBorder: _border(p.danger),
        focusedErrorBorder: _border(p.danger),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final radius = BorderRadius.circular(14);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: p.isDark ? 0.40 : 0.32),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: 49,
          decoration: BoxDecoration(
            gradient: FairTixPalette.buttonGradient,
            borderRadius: radius,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
