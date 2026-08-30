import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dashed-border upload box used on the Identity Verification screen.
class DashedUploadBox extends StatelessWidget {
  const DashedUploadBox({
    super.key,
    required this.onTap,
    this.label = 'Tap to upload your ID',
    this.fileName,
    this.previewBytes,
  });

  final VoidCallback onTap;
  final String label;
  final String? fileName;

  /// Raw image bytes for the picked file. When provided, a thumbnail
  /// preview is shown instead of the upload icon/placeholder text.
  final Uint8List? previewBytes;

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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.inputFillLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: previewBytes != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(previewBytes!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          fileName ?? 'ID photo selected — tap to change',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
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
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
