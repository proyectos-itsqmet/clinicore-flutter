import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The tone of a kicker.
///
/// [warn] exists for one specific reason worth knowing: a caution label on a
/// dark surface CANNOT use [AppColors.emergency], which measures 2.19:1 on
/// navy-deep and fails even the large-text bar. `gold-deep` measures 6.54:1
/// there and is the system's answer to "gold on a dark background".
enum AppKickerTone {
  /// `ink-3` — the default, used almost everywhere.
  muted,

  /// `gold-ink` — for the warm / cream band.
  gold,

  /// `blue-bright` — over the dark hero or CTA sections.
  accent,

  /// `blue-soft` — the hero eyebrow tone.
  soft,

  /// `gold-deep` — a caution label on a dark surface.
  warn,

  /// `surface` — plain white, over photography.
  onDark,
}

/// The uppercase, letter-spaced label that sits above a section heading.
///
/// `size` overrides ONLY the font size. The `.14em` tracking, the 700 weight
/// and the uppercase transform — the things that actually make a kicker a
/// kicker — always come from [AppTypography.kicker]. The booking widget's
/// step labels (`1 / Medico`) are this atom at 11px; leave `size` unset and
/// you get the mobile board's 12px, which is what every other caller wants.
class AppKicker extends StatelessWidget {
  const AppKicker({
    super.key,
    required this.text,
    this.tone = AppKickerTone.muted,
    this.size,
    this.leading,
  });

  final String text;
  final AppKickerTone tone;
  final double? size;

  /// An `AppLiveDot` or icon before the label, as the hero eyebrow does.
  final Widget? leading;

  Color get _color => switch (tone) {
    AppKickerTone.muted => AppColors.ink3,
    AppKickerTone.gold => AppColors.goldInk,
    AppKickerTone.accent => AppColors.blueBright,
    AppKickerTone.soft => AppColors.blueSoft,
    AppKickerTone.warn => AppColors.goldDeep,
    AppKickerTone.onDark => AppColors.surface,
  };

  @override
  Widget build(BuildContext context) {
    // `text-transform: uppercase` — done here rather than asking every caller
    // to shout in the source, so the strings stay readable and translatable.
    final Widget label = Text(
      text.toUpperCase(),
      style: AppTypography.kicker.copyWith(color: _color, fontSize: size),
    );

    if (leading == null) return label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 9,
      children: <Widget>[
        IconTheme.merge(
          data: IconThemeData(color: _color, size: 14),
          child: leading!,
        ),
        label,
      ],
    );
  }
}
