import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dashed-border upload box used on the Identity Verification screen.
class DashedUploadBox extends StatelessWidget {
  const DashedUploadBox({
    super.key,
    required this.onTap,
    this.label = 'Tap to upload your ID',
    this.fileName,
  });

  final VoidCallback onTap;
  final String label;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.accentPurple),
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.inputFillLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_upload_outlined, color: AppColors.accentPurple, size: 36),
                const SizedBox(height: 10),
                Text(
                  fileName ?? label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _dashPath(path, dashLength: 6, gapLength: 5);
    canvas.drawPath(dashedPath, paint);
  }

  Path _dashPath(Path source, {required double dashLength, required double gapLength}) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double length = draw ? dashLength : gapLength;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
