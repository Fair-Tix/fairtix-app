import 'package:flutter/material.dart';

import '../theme/fairtix_palette.dart';

/// The FT ticket mark.
///
/// Uses two pre-trimmed, transparent official logo files so nothing has to be
/// cropped, clipped or tinted in code:
///  - `fairtix_logo_light.png` for light mode (original darker logo)
///  - `fairtix_logo_dark.png`  for dark mode (lighter logo)
///
/// Both files are trimmed to the ticket edges, so [width] is the width of the
/// visible ticket and the height follows the image's aspect ratio.
class FairTixMark extends StatelessWidget {
  const FairTixMark({super.key, this.width = 224});

  /// Width of the visible ticket, in logical pixels.
  final double width;

  static const String _lightAsset = 'assets/icon/fairtix_logo_light.png';
  static const String _darkAsset = 'assets/icon/fairtix_logo_dark.png';

  // Trimmed logo files are 512 x 346 px (height / width).
  static const double _aspect = 346 / 512;

  @override
  Widget build(BuildContext context) {
    final isDark = FairTixPalette.of(context).isDark;

    return SizedBox(
      width: width,
      height: width * _aspect,
      child: Image.asset(
        isDark ? _darkAsset : _lightAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'FairTix',
        // Fallback if the new logo files have not been added yet.
        errorBuilder: (_, _, _) => Image.asset(
          'assets/icon/fairtix_logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
