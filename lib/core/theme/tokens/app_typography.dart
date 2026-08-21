import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Design system type scale.
///
/// IMPORTANT — this is the **mobile** scale, taken from
/// `design/Mobile.dc.html` (the 390px board), NOT the desktop scale in the
/// Angular app's `shared/tokens/tokens.json`. The two boards deliberately
/// disagree:
///
/// | level  | desktop | mobile |
/// |--------|---------|--------|
/// | h1     | 66px    | 40px   |
/// | h2     | 44px    | 30px   |
/// | h3     | 22px    | 19px   |
/// | lead   | 20px    | 18px   |
/// | body   | 17px    | 16px   |
/// | kicker | 13px    | 12px   |
///
/// `meta` (14px) and `cap` (13px) are the only levels that hold across both.
/// Shipping the desktop numbers on a phone is the classic port mistake, so
/// the mobile board wins here — it is the one that was drawn at 390px.
///
/// CSS `letter-spacing` is relative (`em`); Flutter's is absolute (logical
/// pixels). Every value below is therefore `em x fontSize`, pre-computed —
/// the arithmetic is left in a comment so it can be re-checked whenever a
/// size changes.
abstract final class AppTypography {
  /// Headings (h1, h2, h3) and tabular figures. `--font-display`.
  static const String display = 'Nunito';

  /// Everything else: lead, body, meta, cap, kicker. `--font-sans`.
  static const String sans = 'Figtree';

  /// Hero headline. Mobile board: 40px / 1.05 / -.02em / 800.
  static const TextStyle h1 = TextStyle(
    fontFamily: display,
    fontSize: 40,
    height: 1.05,
    letterSpacing: -0.8, // -.02em x 40
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  /// Section heading. Mobile board: 30px / 1.12 / -.016em / 800.
  static const TextStyle h2 = TextStyle(
    fontFamily: display,
    fontSize: 30,
    height: 1.12,
    letterSpacing: -0.48, // -.016em x 30
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  /// Card or subsection heading. Mobile board: 19px / 1.24 / -.008em / 700.
  static const TextStyle h3 = TextStyle(
    fontFamily: display,
    fontSize: 19,
    height: 1.24,
    letterSpacing: -0.152, // -.008em x 19
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// Intro paragraph under an h1 or h2. Mobile board: 18px / 1.5 / 500.
  ///
  /// The desktop board tracks this at `-.004em`; the mobile board drops the
  /// tracking entirely, so it is absent here too.
  static const TextStyle lead = TextStyle(
    fontFamily: sans,
    fontSize: 18,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: AppColors.ink2,
  );

  /// Body paragraph. Mobile board: 16px / 1.6 / 400.
  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: AppColors.ink2,
  );

  /// Metadata (e.g. "Sede Norte / lun-sab"). 14px / 1.45 / 500.
  static const TextStyle meta = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.ink3,
  );

  /// Small auxiliary text (captions, footnotes). 13px / 1.4 / 400.
  static const TextStyle cap = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.ink3,
  );

  /// Short uppercase label above a section heading.
  /// Mobile board: 12px / .14em / 700, uppercased.
  ///
  /// The `.14em` tracking, the 700 weight and the uppercase transform are
  /// what make a kicker a kicker. `AppKicker` applies the transform; this
  /// style carries the rest.
  static const TextStyle kicker = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 1.2,
    letterSpacing: 1.68, // .14em x 12
    fontWeight: FontWeight.w700,
    color: AppColors.ink3,
  );

  /// Tabular figure. The caller always sets the size (the boards use it at
  /// 18, 24, 28...), because a figure's size is what makes it read as a
  /// figure — there is no sensible single default.
  ///
  /// [FontFeature.tabularFigures] is the whole point: it is the Flutter
  /// equivalent of `font-variant-numeric: tabular-nums`, and without it a
  /// counter or a live turn number jitters as its digits change.
  static const TextStyle fig = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w800,
    height: 1,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Button label. Mobile board `.btn`: 16px / 700.
  static const TextStyle button = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Pill label. Mobile board `.pill`: 14px / 600.
  static const TextStyle pill = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Chip label. Mobile board `.chip`: 15px / 600.
  static const TextStyle chip = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
