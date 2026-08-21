import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Design system elevation.
///
/// The CSS reads `rgb(12 43 75 / .07)` and `rgb(0 113 206 / .34)`. Those are
/// not arbitrary greys: `rgb(12 43 75)` IS `#0C2B4B` — [AppColors.navyDeep] —
/// and `rgb(0 113 206)` IS `#0071CE` — [AppColors.blue]. The system's shadows
/// are tinted with brand tokens, so they are composed from those tokens here
/// instead of being restated as literals.
///
/// CSS `box-shadow` is `offset-x offset-y blur spread color`, and each layer
/// maps to one [BoxShadow] — the mapping the Angular token sheet prescribes
/// for this port. CSS blur-radius and Flutter's `blurRadius` are not defined
/// identically (CSS blur is roughly 2 sigma), but the numbers are carried
/// across unchanged as specified.
abstract final class AppShadows {
  /// `--shadow-lift-1` — the default card elevation. Two layers.
  static final List<BoxShadow> lift1 = [
    BoxShadow(
      offset: const Offset(0, 2),
      blurRadius: 6,
      color: AppColors.navyDeep.withValues(alpha: 0.07),
    ),
    BoxShadow(
      offset: const Offset(0, 14),
      blurRadius: 28,
      spreadRadius: -8,
      color: AppColors.navyDeep.withValues(alpha: 0.14),
    ),
  ];

  /// `--shadow-lift-2` — raised elevation (pressed card, floating panel).
  static final List<BoxShadow> lift2 = [
    BoxShadow(
      offset: const Offset(0, 6),
      blurRadius: 14,
      color: AppColors.navyDeep.withValues(alpha: 0.10),
    ),
    BoxShadow(
      offset: const Offset(0, 28),
      blurRadius: 52,
      spreadRadius: -12,
      color: AppColors.navyDeep.withValues(alpha: 0.22),
    ),
  ];

  /// `--shadow-cta` — the coloured halo behind the primary CTA. Its colour is
  /// the CTA's own fill, which is what makes it read as a glow rather than a
  /// drop shadow.
  static final List<BoxShadow> cta = [
    BoxShadow(
      offset: const Offset(0, 6),
      blurRadius: 18,
      color: AppColors.blue.withValues(alpha: 0.34),
    ),
  ];

  /// The mobile board's `.seg-thumb`: `0 2px 8px rgb(12 43 75 / .16)`.
  static final List<BoxShadow> thumb = [
    BoxShadow(
      offset: const Offset(0, 2),
      blurRadius: 8,
      color: AppColors.navyDeep.withValues(alpha: 0.16),
    ),
  ];

  /// The mobile board's `.fab`: `0 8px 24px rgb(12 43 75 / .28)`.
  static final List<BoxShadow> fab = [
    BoxShadow(
      offset: const Offset(0, 8),
      blurRadius: 24,
      color: AppColors.navyDeep.withValues(alpha: 0.28),
    ),
  ];
}
