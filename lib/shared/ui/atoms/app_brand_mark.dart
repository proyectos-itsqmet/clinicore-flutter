import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The brand mark: a rounded white tile with a blue medical cross.
///
/// Drawn from the boards' inline SVG rather than shipped as an asset, because
/// it is four numbers and no curves:
///
/// ```html
/// <svg viewBox="0 0 32 32">
///   <rect width="32" height="32" rx="10" fill="#FFFFFF" />
///   <path d="M16 8.5v15M8.5 16h15" stroke="#0071CE" stroke-width="3.4"
///         stroke-linecap="round" />
/// </svg>
/// ```
///
/// Every proportion below is that viewBox divided by 32, so the mark scales
/// without the cross drifting off-centre or the corner radius going soft.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.size = 32,
    this.tileColor = AppColors.surface,
    this.crossColor = AppColors.blue,
  });

  final double size;

  /// Inverted for a mark sitting on a light ground: pass [AppColors.blue] as
  /// the tile and [AppColors.surface] as the cross.
  final Color tileColor;
  final Color crossColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(tile: tileColor, cross: crossColor),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.tile, required this.cross});

  final Color tile;
  final Color cross;

  // The SVG's 32-unit viewBox, expressed as ratios.
  static const double _radiusRatio = 10 / 32;
  static const double _strokeRatio = 3.4 / 32;
  static const double _armRatio = 15 / 32; // total arm length
  static const double _centreRatio = 16 / 32;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(s * _radiusRatio),
      ),
      Paint()..color = tile,
    );

    final Paint stroke = Paint()
      ..color = cross
      ..strokeWidth = s * _strokeRatio
      ..strokeCap = StrokeCap.round;

    final double c = s * _centreRatio;
    final double half = s * _armRatio / 2;

    canvas.drawLine(Offset(c, c - half), Offset(c, c + half), stroke);
    canvas.drawLine(Offset(c - half, c), Offset(c + half, c), stroke);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.tile != tile || oldDelegate.cross != cross;
}
