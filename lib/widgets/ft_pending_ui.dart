import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Widgets for Registration Step 5 (ID under review), dark design.
/// Presentation only: no logic, navigation or services live here.

/// Fades its child in (and optionally slides it up / scales it up) during one
/// slice of a parent controller, so several widgets can be staggered off a
/// single [animation]. [startMs] / [endMs] are positions inside [totalMs].
class FtReveal extends StatelessWidget {
  const FtReveal({
    super.key,
    required this.animation,
    required this.startMs,
    required this.endMs,
    required this.totalMs,
    required this.child,
    this.slide = 0,
    this.scaleFrom = 1,
  });

  final Animation<double> animation;
  final int startMs;
  final int endMs;
  final int totalMs;
  final Widget child;

  /// Distance in px the child travels upward while appearing.
  final double slide;

  /// Starting scale; 1 means no scaling.
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    final a = animation.drive(
      CurveTween(
        curve: Interval(
          startMs / totalMs,
          endMs / totalMs,
          curve: Curves.easeOut,
        ),
      ),
    );
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        child: child,
        builder: (context, child) {
          final t = a.value;
          Widget w = child!;
          if (scaleFrom != 1) {
            w = Transform.scale(scale: scaleFrom + (1 - scaleFrom) * t, child: w);
          }
          return Transform.translate(offset: Offset(0, slide * (1 - t)), child: w);
        },
      ),
    );
  }
}

/// 100px circle with the clock icon and a slow, pulsing purple glow.
/// [pulse] should loop (0 -> 1 -> 0); a stopped controller gives a still glow.
class FtPendingClock extends StatelessWidget {
  const FtPendingClock({super.key, required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final theme = FtAuthTheme.of(context);
    return Semantics(
      label: 'Review pending',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: pulse,
        child: Icon(
          Icons.schedule_outlined,
          size: 38,
          color: theme.activeAccent,
        ),
        builder: (context, icon) {
          final t = Curves.easeInOut.transform(pulse.value);
          return Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FtColors.progressStart.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(
                  color: FtColors.progressStart.withValues(alpha: 0.12 + 0.2 * t),
                  blurRadius: 22 + 18 * t,
                  spreadRadius: 1 + 4 * t,
                ),
              ],
            ),
            child: icon,
          );
        },
      ),
    );
  }
}

enum FtStageState { done, active, pending }

/// The rounded four-stage card: ID submitted, Selfie captured, Review in
/// progress, Account activated.
///
/// [entrance] drives the one-time check pop-ins (timed with [totalMs]);
/// [spin] drives the endless rotation of the active indicator.
class FtVerificationCard extends StatelessWidget {
  const FtVerificationCard({
    super.key,
    required this.entrance,
    required this.totalMs,
    required this.spin,
  });

  final Animation<double> entrance;
  final int totalMs;
  final Animation<double> spin;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Column(
        children: [
          _StageRow(
            label: 'ID submitted',
            state: FtStageState.done,
            entrance: entrance,
            totalMs: totalMs,
            popStartMs: 650,
            spin: spin,
          ),
          _StageRow(
            label: 'Selfie captured',
            state: FtStageState.done,
            entrance: entrance,
            totalMs: totalMs,
            popStartMs: 760,
            spin: spin,
          ),
          _StageRow(
            label: 'Review in progress',
            state: FtStageState.active,
            entrance: entrance,
            totalMs: totalMs,
            spin: spin,
          ),
          _StageRow(
            label: 'Account activated',
            state: FtStageState.pending,
            entrance: entrance,
            totalMs: totalMs,
            spin: spin,
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.state,
    required this.entrance,
    required this.totalMs,
    required this.spin,
    this.popStartMs = 0,
  });

  final String label;
  final FtStageState state;
  final Animation<double> entrance;
  final int totalMs;
  final Animation<double> spin;
  final int popStartMs;

  static const double _rowHeight = 55;
  static const double _iconSize = 30;

  String get _status => switch (state) {
        FtStageState.done => 'completed',
        FtStageState.active => 'in progress',
        FtStageState.pending => 'pending',
      };

  TextStyle _style(FtAuthTheme t) {
    final base = GoogleFonts.plusJakartaSans(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: t.titleColor,
    );
    return switch (state) {
      FtStageState.done => base,
      FtStageState.active => base.copyWith(fontWeight: FontWeight.w800),
      FtStageState.pending => base.copyWith(color: t.secondaryText),
    };
  }

  Widget _icon(FtAuthTheme t) {
    switch (state) {
      case FtStageState.done:
        // Scales in once (about 300 ms), after the card has appeared.
        final pop = entrance
            .drive(
              CurveTween(
                curve: Interval(
                  popStartMs / totalMs,
                  (popStartMs + 300) / totalMs,
                  curve: Curves.easeOutBack,
                ),
              ),
            )
            .drive(Tween<double>(begin: 0, end: 1));
        return ScaleTransition(
          scale: pop,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: FtColors.progressStart,
            ),
            child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
          ),
        );
      case FtStageState.active:
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: spin,
            builder: (context, _) => CustomPaint(
              painter: _SpinnerPainter(spin.value, t.progressTrack),
            ),
          ),
        );
      case FtStageState.pending:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.surfaceBorder, width: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Semantics(
      label: '$label, $_status',
      excludeSemantics: true,
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          children: [
            SizedBox(width: _iconSize, height: _iconSize, child: _icon(t)),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: _style(t))),
          ],
        ),
      ),
    );
  }
}

/// Active "review in progress" indicator: a dim track, a soft outer halo and
/// a purple arc (fading from #8138ED to #C69AFF at its head) that rotates.
class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.turns, this.trackColor);

  final double turns;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const radius = 10.5;
    const stroke = 3.0;

    canvas.drawCircle(
      c,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = FtColors.progressStart.withValues(alpha: 0.22),
    );

    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turns * 2 * math.pi);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            FtColors.progressStart.withValues(alpha: 0),
            FtColors.progressStart,
            FtColors.progressEnd,
          ],
          stops: const [0.0, 0.5, 0.75],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.turns != turns || old.trackColor != trackColor;
}
