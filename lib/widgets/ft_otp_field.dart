import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Six-box one-time-code input (dark design, Registration Step 2).
///
/// Under the boxes sits ONE invisible text field. That is what makes typing,
/// backspace, pasting a whole code and the keyboard's / OS one-time-code
/// autofill all behave correctly, and it gives screen readers a single
/// "verification code" field instead of six. The boxes only draw what the
/// field holds: the active box is the next empty one, digits are numeric
/// only, and anything past six digits is dropped.
class FtOtpField extends StatelessWidget {
  const FtOtpField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
    this.readOnly = false,
  });

  static const int length = 6;

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called after every change, including a pasted code.
  final ValueChanged<String> onChanged;

  /// Turns every box border red (wrong code).
  final bool hasError;

  /// Ignores typing (while verifying) without closing the keyboard.
  final bool readOnly;

  Future<void> _pasteFromClipboard() async {
    if (readOnly) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final code = digits.length > length ? digits.substring(0, length) : digits;
    controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final text = controller.text;
        final complete = text.length == length;
        final activeIndex = math.min(text.length, length - 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final boxWidth = ((constraints.maxWidth - gap * (length - 1)) / length)
                .clamp(40.0, 64.0);
            final boxHeight = boxWidth * 1.22;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _pasteFromClipboard,
              child: SizedBox(
                height: boxHeight,
                child: Stack(
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (var i = 0; i < length; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            _OtpBox(
                              width: boxWidth,
                              height: boxHeight,
                              digit: i < text.length ? text[i] : '',
                              active: focusNode.hasFocus && i == activeIndex,
                              // All six light up together once the code is full.
                              highlight: complete && !hasError,
                              error: hasError,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: Semantics(
                        label: 'Verification code, $length digits',
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          readOnly: readOnly,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(length),
                          ],
                          showCursor: false,
                          enableInteractiveSelection: false,
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                          ),
                          cursorColor: Colors.transparent,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.width,
    required this.height,
    required this.digit,
    required this.active,
    required this.highlight,
    required this.error,
  });

  final double width;
  final double height;
  final String digit;
  final bool active;
  final bool highlight;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final lit = (active || highlight) && !error;
    final border = error
        ? FtColors.danger
        : lit
            ? FtColors.otpActive
            : FtColors.otpBorder;

    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FtColors.otpFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border, width: 1),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: FtColors.progressStart.withValues(alpha: 0.38),
                  blurRadius: 16,
                ),
              ]
            : const [],
      ),
      child: digit.isEmpty
          ? null
          : _PopDigit(key: ValueKey(digit), digit: digit, animate: !reduce),
    );
  }
}

/// A digit that scales 0.95 -> 1.0 the moment it appears.
class _PopDigit extends StatelessWidget {
  const _PopDigit({super.key, required this.digit, required this.animate});

  final String digit;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animate ? 0.95 : 1, end: 1),
      duration: animate ? const Duration(milliseconds: 170) : Duration.zero,
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Text(
        digit,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Full-width pill button for the verify step: dims until [enabled], scales
/// to 0.97 while pressed, shows a spinner while [loading], and an animated
/// green check once [success] is true.
class FtVerifyButton extends StatefulWidget {
  const FtVerifyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.success = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool loading;
  final bool success;

  @override
  State<FtVerifyButton> createState() => _FtVerifyButtonState();
}

class _FtVerifyButtonState extends State<FtVerifyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final busy = widget.loading || widget.success;
    final canTap = widget.enabled && !busy;
    final radius = BorderRadius.circular(30);

    final Widget content;
    if (widget.success) {
      content = const _AnimatedCheck(key: ValueKey('success'));
    } else if (widget.loading) {
      content = const SizedBox(
        key: ValueKey('loading'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
    } else {
      content = Text(
        widget.label,
        key: const ValueKey('label'),
        style: FtText.button(),
      );
    }

    return Semantics(
      button: true,
      enabled: canTap,
      label: widget.success
          ? 'Email verified'
          : widget.loading
              ? 'Verifying'
              : widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed && canTap && !reduce ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: (widget.enabled || busy) ? 1 : 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FtColors.progressStart, FtColors.otpButtonEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: FtColors.glow.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: canTap ? widget.onPressed : null,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                child: SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White disc with a green check that draws itself.
class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 500),
      builder: (context, t, _) =>
          CustomPaint(size: const Size.square(34), painter: _CheckPainter(t)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  static const Color _green = Color(0xFF22C55E);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final discT = Curves.easeOutBack.transform((t * 2).clamp(0.0, 1.0));
    canvas.drawCircle(
      center,
      size.width / 2 * discT,
      Paint()..color = Colors.white,
    );

    final checkT = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    if (checkT <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * Curves.easeOut.transform(checkT)),
      Paint()
        ..color = _green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
