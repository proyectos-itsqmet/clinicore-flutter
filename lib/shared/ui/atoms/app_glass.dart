import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The translucent surface that sits over dark photography — the boards'
/// `.glass`:
///
/// ```css
/// .glass {
///   background-color: rgb(255 255 255 / .18);
///   backdrop-filter: blur(18px) saturate(180%);
///   border: 1px solid rgb(255 255 255 / .34);
/// }
/// ```
///
/// It lives in its own atom because three different things use it (the nav
/// bar, the hero pills, the `glass` button variant) and the blur has one
/// non-obvious conversion in it that must not be re-derived per call site:
///
/// **CSS `blur(18px)` is not `ImageFilter.blur(sigmaX: 18)`.** The CSS blur
/// radius is defined as roughly twice the Gaussian standard deviation, while
/// Flutter's `sigmaX`/`sigmaY` *are* the standard deviation. Passing 18
/// straight through produces a blur about twice as heavy as the design, which
/// on a photo reads as frosted plastic instead of glass. The conversion is
/// [_blurSigma].
///
/// The `saturate(180%)` half matters more than it looks: without it the blur
/// averages the photo underneath into grey and the glass loses the colour it
/// is supposed to be borrowing.
class AppGlass extends StatelessWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.pillAll,
    this.padding,
    this.showBorder = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// The `1px solid rgb(255 255 255 / .34)` hairline. Off for cases that
  /// supply their own border (or none).
  final bool showBorder;

  /// `blur(18px)` in CSS terms, expressed as the Gaussian sigma Flutter
  /// actually wants.
  static const double _blurSigma = 9;

  /// `saturate(180%)`.
  static const double _saturation = 1.8;

  /// `rgb(255 255 255 / .18)`.
  static const double _fillAlpha = 0.18;

  /// `1px solid rgb(255 255 255 / .34)`.
  static const double _borderAlpha = 0.34;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          inner: ColorFilter.matrix(_saturationMatrix(_saturation)),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: _fillAlpha),
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(
                    color: AppColors.surface.withValues(alpha: _borderAlpha),
                  )
                : null,
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// The standard SVG/CSS saturation matrix, which is what `filter: saturate()`
/// is specified in terms of. Written out as arithmetic rather than as twenty
/// magic numbers so the value can be changed in one place.
List<double> _saturationMatrix(double s) {
  // Luminance coefficients from the filter-effects spec.
  const double lr = 0.213;
  const double lg = 0.715;
  const double lb = 0.072;

  return <double>[
    lr + (1 - lr) * s, lg * (1 - s), lb * (1 - s), 0, 0, //
    lr * (1 - s), lg + (1 - lg) * s, lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s), lb + (1 - lb) * s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
