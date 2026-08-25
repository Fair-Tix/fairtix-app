import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Deterministic pseudo-QR pattern used as a visual stand-in for a real
/// ticket QR code. The same [seed] always paints the same pattern, so
/// switching between tickets visibly changes the code.
///
/// TODO: replace with a real qr_flutter `QrImageView` rendering the
/// server-signed `qr_code_token` once the QR signing Cloud Function is
/// wired up. See the Technology Stack section of the capstone proposal
/// for the intended qr_flutter / mobile_scanner integration.
class QrPlaceholder extends StatelessWidget {
  const QrPlaceholder({super.key, required this.seed, this.size = 200, this.moduleCount = 21});

  final String seed;
  final double size;
  final int moduleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorderLight),
      ),
      child: CustomPaint(
        painter: _QrPainter(seed: seed, moduleCount: moduleCount),
        size: Size.infinite,
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.seed, required this.moduleCount});

  final String seed;
  final int moduleCount;

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = AppColors.textDark;
    final moduleSize = size.width / moduleCount;
    final bits = _seededBits(seed, moduleCount * moduleCount);

    for (int row = 0; row < moduleCount; row++) {
      for (int col = 0; col < moduleCount; col++) {
        if (_inFinderZone(row, col)) continue;
        if (bits[row * moduleCount + col]) {
          canvas.drawRect(
            Rect.fromLTWH(col * moduleSize, row * moduleSize, moduleSize, moduleSize),
            darkPaint,
          );
        }
      }
    }

    for (final corner in [(0, 0), (0, moduleCount - 7), (moduleCount - 7, 0)]) {
      _drawFinder(canvas, corner.$1, corner.$2, moduleSize, darkPaint);
    }
  }

  bool _inFinderZone(int row, int col) {
    bool inCorner(int r, int c) => row >= r && row < r + 7 && col >= c && col < c + 7;
    return inCorner(0, 0) || inCorner(0, moduleCount - 7) || inCorner(moduleCount - 7, 0);
  }

  void _drawFinder(Canvas canvas, int r, int c, double moduleSize, Paint darkPaint) {
    canvas.drawRect(Rect.fromLTWH(c * moduleSize, r * moduleSize, moduleSize * 7, moduleSize * 7), darkPaint);
    final whitePaint = Paint()..color = AppColors.white;
    canvas.drawRect(
      Rect.fromLTWH((c + 1) * moduleSize, (r + 1) * moduleSize, moduleSize * 5, moduleSize * 5),
      whitePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH((c + 2) * moduleSize, (r + 2) * moduleSize, moduleSize * 3, moduleSize * 3),
      darkPaint,
    );
  }

  List<bool> _seededBits(String seed, int count) {
    int hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final bits = <bool>[];
    for (int i = 0; i < count; i++) {
      hash = (hash * 1103515245 + 12345) & 0x7fffffff;
      bits.add(((hash >> 16) & 1) == 1);
    }
    return bits;
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.seed != seed;
}
