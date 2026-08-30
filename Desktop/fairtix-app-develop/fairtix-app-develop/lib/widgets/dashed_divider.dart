import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thin horizontal dashed rule, used to separate the ticket header from
/// the QR section on the Ticket Detail screen.
class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.color = AppColors.accentPurple,
    this.height = 1.4,
    this.dashWidth = 6,
    this.gap = 4,
  });

  final Color color;
  final double height;
  final double dashWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segment = dashWidth + gap;
        final dashCount = (constraints.maxWidth / segment).floor();
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Wrap(
            spacing: gap,
            runSpacing: 0,
            children: List.generate(
              dashCount,
              (_) => Container(width: dashWidth, height: height, color: color),
            ),
          ),
        );
      },
    );
  }
}
