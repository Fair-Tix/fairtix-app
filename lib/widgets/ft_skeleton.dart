import 'package:flutter/material.dart';

import '../theme/fairtix_palette.dart';
import 'ft_dark_ui.dart' show FtAuthTheme;
import 'ft_ticket_card.dart';

/// Skeleton ("shimmer") loading blocks shared by the whole app.
///
/// Usage: wrap the placeholder layout in one [FtShimmer], and build it out of
/// [FtSkeletonBox] / [FtSkeletonCircle] (or the ready-made shapes below). All
/// blocks inside the same [FtShimmer] sweep in sync. Outside a [FtShimmer] a
/// block is drawn flat. With "reduce motion" on, blocks are drawn flat too.
///
/// Colors come from [FairTixPalette], so Light and Dark both work.
class FtShimmer extends StatefulWidget {
  const FtShimmer({
    super.key,
    required this.child,
    this.semanticLabel = 'Loading',
  });

  final Widget child;

  /// Read out by screen readers instead of the individual blocks.
  final String semanticLabel;

  @override
  State<FtShimmer> createState() => _FtShimmerState();
}

class _FtShimmerState extends State<FtShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: _ShimmerScope(
          controller: _reduceMotion ? null : _controller,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ShimmerScope extends InheritedNotifier<AnimationController> {
  const _ShimmerScope({
    required AnimationController? controller,
    required super.child,
  }) : super(notifier: controller);
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.slide);

  /// -1 = highlight fully left of the block, +1 = fully right of it.
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// One rounded placeholder block.
class FtSkeletonBox extends StatelessWidget {
  const FtSkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.borderRadius,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;

  /// Overrides [radius] (e.g. a poster that is only rounded on top).
  final BorderRadiusGeometry? borderRadius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final base = p.isDark ? const Color(0xFF21175A) : const Color(0xFFEAE3FC);
    final highlight =
        p.isDark ? const Color(0xFF35278A) : const Color(0xFFF8F5FF);

    final controller =
        context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.notifier;

    final Gradient? gradient = controller == null
        ? null
        : LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.25, 0.5, 0.75],
            transform: _SlideGradientTransform(
              -1.0 + 2.0 * Curves.easeInOut.transform(controller.value),
            ),
          );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: gradient == null ? base : null,
        gradient: gradient,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius:
            circle ? null : (borderRadius ?? BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Round placeholder (avatars).
class FtSkeletonCircle extends StatelessWidget {
  const FtSkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      FtSkeletonBox(width: size, height: size, circle: true);
}

/// Placeholder in the exact shape of [FtTicketCard] (poster, info row, footer),
/// so the layout doesn't jump when the real cards arrive. Phone app only.
class FtSkeletonTicketCard extends StatelessWidget {
  const FtSkeletonTicketCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return CustomPaint(
      painter: FtTicketShapePainter(fill: t.cardFill, border: t.surfaceBorder),
      child: const SizedBox(
        height: kFtPosterHeight + kFtInfoHeight + kFtFooterHeight,
        child: Column(
          children: [
            FtSkeletonBox(
              height: kFtPosterHeight,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(kFtCardRadius)),
            ),
            SizedBox(
              height: kFtInfoHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    FtSkeletonBox(width: 80),
                    SizedBox(width: 24),
                    FtSkeletonBox(width: 56),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: kFtFooterHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    FtSkeletonBox(width: 110),
                    Spacer(),
                    FtSkeletonBox(width: 104, height: 36, radius: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One list row: round or rounded-square leading block, two text lines, and an
/// optional trailing block (amount / status). Phone app and web.
class FtSkeletonListRow extends StatelessWidget {
  const FtSkeletonListRow({
    super.key,
    this.leadingSize = 44,
    this.leadingCircle = true,
    this.showTrailing = true,
    this.showLeading = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final double leadingSize;
  final bool leadingCircle;
  final bool showTrailing;
  final bool showLeading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showLeading) ...[
            FtSkeletonBox(
              width: leadingSize,
              height: leadingSize,
              circle: leadingCircle,
              radius: 12,
            ),
            const SizedBox(width: 14),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FtSkeletonBox(width: 150, height: 14),
                SizedBox(height: 8),
                FtSkeletonBox(width: 100, height: 11),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FtSkeletonBox(width: 64, height: 14),
                SizedBox(height: 8),
                FtSkeletonBox(width: 44, height: 11),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Two side-by-side summary tiles (e.g. Home's "My Tickets / Listed for
/// resale" counters). Uses [FairTixPalette].
class FtSkeletonStatRow extends StatelessWidget {
  const FtSkeletonStatRow({super.key, this.height = 84});

  final double height;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    Widget tile() => Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FtSkeletonBox(width: 90, height: 11),
                SizedBox(height: 12),
                FtSkeletonBox(width: 40, height: 22),
              ],
            ),
          ),
        );
    return Row(children: [tile(), const SizedBox(width: 12), tile()]);
  }
}

/// Placeholder for a Home feed post ([FtEventPostCard]): organizer header,
/// poster, title/date/venue lines and the footer with the button.
class FtSkeletonPostCard extends StatelessWidget {
  const FtSkeletonPostCard({super.key, this.posterAspect = 1.0});

  /// Width / height of the poster block.
  final double posterAspect;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                FtSkeletonCircle(size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FtSkeletonBox(width: 120, height: 13),
                    SizedBox(height: 7),
                    FtSkeletonBox(width: 80, height: 10),
                  ],
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: posterAspect,
            child: const FtSkeletonBox(height: double.infinity, radius: 0),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FtSkeletonBox(width: 200, height: 18),
                SizedBox(height: 10),
                FtSkeletonBox(width: 140, height: 12),
                SizedBox(height: 8),
                FtSkeletonBox(width: 170, height: 12),
                SizedBox(height: 18),
                Row(
                  children: [
                    FtSkeletonBox(width: 90, height: 28),
                    Spacer(),
                    FtSkeletonBox(width: 120, height: 40, radius: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain bordered panel (surface fill, hairline border) to hold skeleton
/// blocks on the organizer / admin web pages. Palette only, so it needs no
/// FtAuthTheme.
class FtSkeletonPanel extends StatelessWidget {
  const FtSkeletonPanel({
    super.key,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.height,
    this.child,
  });

  final double radius;
  final EdgeInsetsGeometry padding;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    return Container(
      height: height,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// A bordered card holding [rows] skeleton rows with dividers, matching the
/// grouped-card look of Transactions and Notifications. Phone app only.
class FtSkeletonListCard extends StatelessWidget {
  const FtSkeletonListCard({
    super.key,
    this.rows = 6,
    this.leadingSize = 44,
    this.leadingCircle = true,
    this.showTrailing = true,
    this.showLeading = true,
    this.radius = 22,
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.dividerIndent = 0,
  });

  final int rows;
  final double leadingSize;
  final bool leadingCircle;
  final bool showTrailing;
  final bool showLeading;
  final double radius;
  final EdgeInsetsGeometry rowPadding;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final t = FtAuthTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: dividerIndent,
                endIndent: dividerIndent,
                color: t.surfaceBorder,
              ),
            FtSkeletonListRow(
              leadingSize: leadingSize,
              leadingCircle: leadingCircle,
              showTrailing: showTrailing,
              showLeading: showLeading,
              padding: rowPadding,
            ),
          ],
        ],
      ),
    );
  }
}
