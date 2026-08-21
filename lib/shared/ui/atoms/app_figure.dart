import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// A number the user reads as a quantity: a count, a price, a turn number, a
/// day of the month.
///
/// It exists as an atom for one reason — [FontFeature.tabularFigures], which
/// [AppTypography.fig] carries. Without tabular figures, `12 cupos` counting
/// down to `11 cupos` makes the whole line twitch sideways, because a
/// proportional `1` is narrower than a `2`. Any number that changes while the
/// user is looking at it belongs in here.
class AppFigure extends StatelessWidget {
  const AppFigure({
    super.key,
    required this.value,
    required this.size,
    this.color,
    this.suffix,
  });

  final String value;

  /// Always explicit: the boards use this at 18 (day chips), 24 (hero
  /// "cupos", prices) and 28 (counter rings), and the size is what makes a
  /// figure read as a figure.
  final double size;

  final Color? color;

  /// A smaller unit riding on the figure's baseline — the `%` in "96%". The
  /// board sets it to roughly half the figure's size.
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTypography.fig.copyWith(
      fontSize: size,
      color: color,
    );

    if (suffix == null) return Text(value, style: style);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(value, style: style),
        Text(suffix!, style: style.copyWith(fontSize: size * 0.54)),
      ],
    );
  }
}
