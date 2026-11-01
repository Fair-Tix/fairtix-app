import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widgets for the "You're verified" screen and its notification card,
/// dark design. Presentation only: no logic, navigation or services here.

/// The three greens/blues taken from the verified-screen design. Green is
/// used only for success signals (check, shield, badge, notification icon).
class FtVerifiedColors {
  FtVerifiedColors._();

  static const Color green = Color(0xFF36E88B);
  static const Color circle = Color(0xFF1C2D46);
  static const Color badge = Color(0xFF142D2B);
}

/// 100px circle with a green check that draws itself as [draw] runs 0 -> 1.
class FtVerifiedCircle extends StatelessWidget {
  const FtVerifiedCircle({super.key, required this.draw});

  final Animation<double> draw;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified',
      excludeSemantics: true,
      child: Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: FtVerifiedColors.circle,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: draw,
            builder: (context, _) => CustomPaint(
              size: const Size.square(40),
              painter: _CheckPainter(draw.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.54)
      ..lineTo(size.width * 0.40, size.height * 0.78)
      ..lineTo(size.width * 0.86, size.height * 0.26);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t.clamp(0.0, 1.0)),
      Paint()
        ..color = FtVerifiedColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

/// Small green pill: shield icon + "FairTix Verified".
class FtVerifiedBadge extends StatelessWidget {
  const FtVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FtVerifiedColors.badge,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: FtVerifiedColors.green,
          ),
          const SizedBox(width: 8),
          Text(
            'FairTix Verified',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: FtVerifiedColors.green,
            ),
          ),
        ],
      ),
    );
  }
}
