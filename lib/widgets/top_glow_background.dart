import 'package:flutter/material.dart';

import '../theme/fairtix_palette.dart';

/// Page background for redesigned screens: flat page color with a wide, soft
/// elliptical glow fading down from the top. Put it behind content:
///
/// ```dart
/// Stack(children: [const TopGlowBackground(), ...content])
/// ```
///
/// Shape measured from the design files (1440-wide frame): the glow is about
/// 660px wide and 410px tall, easing out smoothly (1 - smoothstep).
///
/// [centerX] is where the glow is centered, as a fraction of this widget's
/// width (0.5 = middle). [radiusX] overrides the horizontal radius in logical
/// pixels (default: 46% of the width). The glow is clipped to this widget.
class TopGlowBackground extends StatelessWidget {
  const TopGlowBackground({super.key, this.centerX = 0.5, this.radiusX});

  final double centerX;
  final double? radiusX;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Positioned.fill(
      child: ClipRect(
        child: ColoredBox(
          color: p.background,
          child: CustomPaint(
            painter: _TopGlowPainter(
              color: p.backgroundGlow,
              centerX: centerX,
              radiusX: radiusX,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopGlowPainter extends CustomPainter {
  const _TopGlowPainter({
    required this.color,
    required this.centerX,
    required this.radiusX,
  });

  final Color color;
  final double centerX;
  final double? radiusX;

  // 1 - smoothstep(d), sampled, d = distance from center / radius.
  static const List<double> _stops = [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1];
  static const List<double> _alphas = [1, 0.99, 0.84, 0.68, 0.5, 0.32, 0.16, 0.04, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final rx = radiusX ?? size.width * 0.46;
    final ry = size.height < 745 ? size.height * 0.55 : 410.0;

    canvas.save();
    canvas.translate(size.width * centerX, 0);
    canvas.scale(rx, ry);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [for (final a in _alphas) color.withValues(alpha: a)],
        stops: _stops,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TopGlowPainter old) =>
      old.color != color || old.centerX != centerX || old.radiusX != radiusX;
}
