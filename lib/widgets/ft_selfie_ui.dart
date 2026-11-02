import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Widgets for Registration Step 4 (selfie), dark design. Presentation only.

/// The big rounded camera-style frame with the dashed face oval. With no
/// photo it shows the oval and [caption]; once [selfieBytes] is set the
/// photo fills the oval inside a solid light-purple outline.
class FtSelfieFrame extends StatelessWidget {
  const FtSelfieFrame({
    super.key,
    required this.caption,
    this.selfieBytes,
  });

  final String caption;
  final Uint8List? selfieBytes;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final hasPhoto = selfieBytes != null;

    return Semantics(
      label: hasPhoto
          ? 'Selfie captured. $caption'
          : 'Selfie frame. $caption',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = (width * 0.915).clamp(280.0, 420.0);
          // Tall oval, as in the design: about 56% of the width, 1.29x taller.
          final ovalW = math.min(width * 0.56, height * 0.6);
          final ovalH = ovalW * 1.29;

          return Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: t.surfaceFill,
              borderRadius: BorderRadius.circular(30),
              // Dark has no outline; on Light the white frame needs one to
              // stand out from the page.
              border: t.isDark ? null : Border.all(color: t.surfaceBorder),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration:
                      reduce ? Duration.zero : const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                      child: child,
                    ),
                  ),
                  child: hasPhoto
                      ? SizedBox(
                          key: const ValueKey('photo'),
                          width: ovalW,
                          height: ovalH,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipOval(
                                child: Image.memory(
                                  selfieBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              CustomPaint(
                                painter: _OvalOutlinePainter(
                                  color: t.activeAccent,
                                  dashed: false,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('oval'),
                          width: ovalW,
                          height: ovalH,
                          child: CustomPaint(
                            painter: _OvalOutlinePainter(
                              color: FtColors.progressStart,
                              dashed: true,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: t.selfieCaption,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OvalOutlinePainter extends CustomPainter {
  _OvalOutlinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }

    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      // Whole number of dashes so the pattern closes evenly around the oval.
      final count = (metric.length / 17).round();
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        final start = i * step;
        canvas.drawPath(metric.extractPath(start, start + step * 0.58), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OvalOutlinePainter old) =>
      old.color != color || old.dashed != dashed;
}

/// "Good lighting / Face the camera / No glasses" row under the frame.
class FtTipsRow extends StatelessWidget {
  const FtTipsRow({super.key, required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: t.secondaryText,
    );
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 6,
        children: [for (final tip in tips) Text(tip, style: style)],
      ),
    );
  }
}
