import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';

/// Widgets for Registration Step 3 (ID verification), dark design.
/// Presentation only: they take the same values the screen already had
/// (selected ID type, picked image bytes, file name) and report taps back.

/// "You're almost there" card: percentage, progress bar and the five
/// registration milestones (done / current / upcoming).
///
/// [completed] is how many milestones are finished; the milestone at
/// [current] (default: the first unfinished one) gets the glowing ring.
class FtProgressCard extends StatefulWidget {
  const FtProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.labels,
    required this.completed,
    this.current,
  });

  final String title;
  final String subtitle;
  final List<String> labels;
  final int completed;
  final int? current;

  @override
  State<FtProgressCard> createState() => _FtProgressCardState();
}

class _FtProgressCardState extends State<FtProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
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
    final t = FtAuthTheme.of(context);
    final total = widget.labels.length;
    final percent = total == 0 ? 0.0 : widget.completed / total;
    final current = widget.current ?? widget.completed;

    final cardFade = _controller.drive(
      CurveTween(curve: const Interval(0, 0.4, curve: Curves.easeOut)),
    );
    final barFill = _controller.drive(
      CurveTween(curve: const Interval(0.1, 1, curve: Curves.easeInOut)),
    );

    final summary = StringBuffer(
      'Registration progress, ${(percent * 100).round()} percent. ',
    );
    for (var i = 0; i < total; i++) {
      final status = i < widget.completed
          ? 'done'
          : i == current
              ? 'current step'
              : 'not started';
      summary.write('${widget.labels[i]} $status. ');
    }

    return Semantics(
      label: summary.toString(),
      excludeSemantics: true,
      child: FadeTransition(
        opacity: cardFade,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: t.cardFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: t.titleColor,
                      ),
                    ),
                  ),
                  Text(
                    '${(percent * 100).round()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: t.activeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: FtText.legal().copyWith(
                  fontSize: 14,
                  color: t.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 9,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: t.progressTrack),
                      ),
                      AnimatedBuilder(
                        animation: barFill,
                        builder: (context, child) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (percent * barFill.value).clamp(0.0, 1.0),
                          child: child,
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.all(Radius.circular(999)),
                            gradient: LinearGradient(
                              colors: [
                                FtColors.progressStart,
                                FtColors.progressEnd,
                              ],
                            ),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: _Milestone(
                        label: widget.labels[i],
                        state: i < widget.completed
                            ? _MilestoneState.done
                            : i == current
                                ? _MilestoneState.current
                                : _MilestoneState.upcoming,
                        appear: _controller.drive(
                          CurveTween(
                            curve: Interval(
                              0.15 + i * 0.08,
                              0.6 + i * 0.08,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        pop: _controller.drive(
                          CurveTween(
                            curve: Interval(
                              0.15 + i * 0.08,
                              0.6 + i * 0.08,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MilestoneState { done, current, upcoming }

class _Milestone extends StatelessWidget {
  const _Milestone({
    required this.label,
    required this.state,
    required this.appear,
    required this.pop,
  });

  final String label;
  final _MilestoneState state;
  final Animation<double> appear;
  final Animation<double> pop;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final Widget circle;
    switch (state) {
      case _MilestoneState.done:
        circle = Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: FtColors.progressStart,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
        );
      case _MilestoneState.current:
        circle = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.surfaceFill,
            border: Border.all(color: t.activeAccent, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: FtColors.progressStart.withValues(alpha: 0.55),
                blurRadius: 14,
              ),
            ],
          ),
        );
      case _MilestoneState.upcoming:
        circle = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.surfaceFill,
            border: Border.all(color: t.surfaceBorder, width: 1.5),
          ),
        );
    }

    final active = state != _MilestoneState.upcoming;
    return FadeTransition(
      opacity: appear,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(pop),
        child: Column(
          children: [
            circle,
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: active ? t.titleColor : t.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded choice pill (ID type). Selecting it animates the colors and gives
/// a small 0.97 -> 1.0 pop with a soft purple glow.
class FtChoicePill extends StatefulWidget {
  const FtChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<FtChoicePill> createState() => _FtChoicePillState();
}

class _FtChoicePillState extends State<FtChoicePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void didUpdateWidget(FtChoicePill old) {
    super.didUpdateWidget(old);
    if (!old.selected &&
        widget.selected &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      excludeSemantics: true,
      child: ScaleTransition(
        scale: _pop.drive(
          Tween<double>(begin: 0.97, end: 1)
              .chain(CurveTween(curve: Curves.easeOut)),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected ? FtColors.progressStart : t.surfaceFill,
              border: Border.all(
                color: selected ? FtColors.progressStart : t.surfaceBorder,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: FtColors.progressStart.withValues(alpha: 0.38),
                        blurRadius: 14,
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedDefaultTextStyle(
              duration:
                  reduce ? Duration.zero : const Duration(milliseconds: 180),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : t.secondaryText,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ID photo area: a dashed card that shows the camera prompt, or the
/// picked photo once there is one. Tapping it always calls [onTap] (the
/// screen's existing camera/gallery picker).
class FtUploadBox extends StatefulWidget {
  const FtUploadBox({
    super.key,
    required this.onTap,
    this.fileName,
    this.previewBytes,
  });

  final VoidCallback onTap;
  final String? fileName;

  /// Raw bytes of the picked photo; when set, shown instead of the prompt.
  final Uint8List? previewBytes;

  @override
  State<FtUploadBox> createState() => _FtUploadBoxState();
}

class _FtUploadBoxState extends State<FtUploadBox> {
  static const double _radius = 24;
  bool _pressed = false;

  Widget _prompt() {
    final t = FtAuthTheme.of(context);
    return Column(
      key: const ValueKey('prompt'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_camera_outlined, color: t.activeAccent, size: 30),
        const SizedBox(height: 14),
        Text(
          'Take a photo or upload',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: t.activeAccent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Make sure all four corners are visible',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w400,
            color: t.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    return Stack(
      key: const ValueKey('preview'),
      fit: StackFit.expand,
      children: [
        Image.memory(widget.previewBytes!, fit: BoxFit.cover),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: FtColors.progressStart,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              widget.fileName ?? 'ID photo selected — tap to change',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final hasPhoto = widget.previewBytes != null;

    return Semantics(
      button: true,
      label: hasPhoto
          ? 'ID photo selected. Tap to change it.'
          : 'Take a photo or upload your ID',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = (constraints.maxWidth * 0.435).clamp(150.0, 220.0);
          return AnimatedScale(
            scale: _pressed && !reduce ? 0.98 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: CustomPaint(
              foregroundPainter: _DashedRRectPainter(
                color: t.activeAccent,
                radius: _radius,
              ),
              child: Material(
                color: t.uploadFill,
                borderRadius: BorderRadius.circular(_radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onTap,
                  onHighlightChanged: (v) => setState(() => _pressed = v),
                  child: SizedBox(
                    width: double.infinity,
                    height: height,
                    child: AnimatedSwitcher(
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.97, end: 1)
                              .animate(animation),
                          child: child,
                        ),
                      ),
                      child: hasPhoto ? _preview() : _prompt(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? 6.0 : 5.0;
        if (draw) {
          dashed.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
