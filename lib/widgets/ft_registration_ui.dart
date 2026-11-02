import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ft_dark_ui.dart';

/// Building blocks for the 5-step eventgoer registration flow. They follow
/// the Light / Dark switch only on screens whose scaffold sets
/// `followTheme: true` (see [FtAuthTheme]); otherwise they stay Dark.
/// Step 1 uses them first; Steps 2-5 should reuse [FtRegistrationScaffold]
/// with their own `step` number so the header and progress bar stay identical.

/// 48px round back button: surface fill, subtle border, chevron.
class FtCircleBackButton extends StatelessWidget {
  const FtCircleBackButton({super.key, required this.onPressed});

  /// Null dims the button and ignores taps (e.g. while submitting).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Back',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.circleFill,
              border: Border.all(color: t.circleBorder),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: t.circleIcon,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded progress bar. It animates from [from] to [value] when it first
/// appears, so moving to the next step visibly fills the bar.
class FtProgressBar extends StatelessWidget {
  const FtProgressBar({super.key, required this.value, this.from});

  /// 0.0 - 1.0.
  final double value;

  /// Where the fill starts animating from. Defaults to [value] (no animation).
  final double? from;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final target = value.clamp(0.0, 1.0);
    final start = (from ?? value).clamp(0.0, 1.0);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);

    return Semantics(
      label: 'Registration progress',
      value: '${(target * 100).round()} percent',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 10,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: t.progressTrack),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: start, end: target),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: child,
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    gradient: LinearGradient(
                      colors: [FtColors.progressStart, FtColors.progressEnd],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page layout for every registration step: back button + "Step X of N" +
/// progress bar, then the heading and form inside a scroll view (so the
/// keyboard never hides the active field), and a bottom bar with the main
/// button and a footer, anchored above the safe area and the keyboard.
///
/// No logo on purpose; the registration design leaves it out.
class FtRegistrationScaffold extends StatelessWidget {
  const FtRegistrationScaffold({
    super.key,
    required this.step,
    this.totalSteps = 5,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.button,
    required this.onBack,
    this.footer,
    this.entrance = false,
    this.subtitleColor,
    this.headerExtra,
    this.followTheme = false,
  });

  /// 1-based current step.
  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final List<Widget> body;
  final Widget button;
  final VoidCallback? onBack;
  final Widget? footer;

  /// Fade the page content in while sliding it up ~20px when the screen opens.
  final bool entrance;

  /// Overrides the subtitle color (defaults to the shared lavender).
  final Color? subtitleColor;

  /// Shown under the back button / step label in place of the thin progress
  /// bar (e.g. Step 3's "You're almost there" card).
  final Widget? headerExtra;

  /// True = follow the Light / Dark switch. False = always Dark, for steps
  /// that have not been reworked for Light yet.
  final bool followTheme;

  @override
  Widget build(BuildContext context) {
    final t = followTheme ? FtAuthTheme.live(context) : FtAuthTheme.dark;
    return FtAuthThemeScope(
      theme: t,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: t.overlayStyle,
        child: Scaffold(
          backgroundColor: t.bgBottom,
          body: FtAuthBackground(
            theme: t,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                      child: FtEntrance(
                        enabled: entrance,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                FtCircleBackButton(onPressed: onBack),
                                const Spacer(),
                                Text(
                                  'Step $step of $totalSteps',
                                  style: t.stepLabel(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            headerExtra ??
                                FtProgressBar(
                                  from: (step - 1) / totalSteps,
                                  value: step / totalSteps,
                                ),
                            const SizedBox(height: 26),
                            Semantics(
                              header: true,
                              child: Text(title, style: t.title()),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: t.subtitle().copyWith(color: subtitleColor),
                            ),
                            const SizedBox(height: 28),
                            ...body,
                          ],
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.divider)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          button,
                          if (footer != null) ...[
                            const SizedBox(height: 14),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades its child in while sliding it up from ~20px below. Honors the
/// system "reduce motion" setting.
class FtEntrance extends StatefulWidget {
  const FtEntrance({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<FtEntrance> createState() => _FtEntranceState();
}

class _FtEntranceState extends State<FtEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final eased = _controller.drive(CurveTween(curve: Curves.easeOut));
    return FadeTransition(
      opacity: eased,
      child: AnimatedBuilder(
        animation: eased,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - eased.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// "By continuing you agree to the Terms and Privacy Policy." with the two
/// names tappable. Center aligned, soft lavender.
class FtLegalText extends StatefulWidget {
  const FtLegalText({
    super.key,
    required this.onTerms,
    required this.onPrivacy,
  });

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<FtLegalText> createState() => _FtLegalTextState();
}

class _FtLegalTextState extends State<FtLegalText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => widget.onTerms();
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => widget.onPrivacy();

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Text.rich(
      TextSpan(
        style: t.legal(),
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(
            text: 'Terms',
            style: t.legalLink(),
            recognizer: _terms,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: t.legalLink(),
            recognizer: _privacy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
