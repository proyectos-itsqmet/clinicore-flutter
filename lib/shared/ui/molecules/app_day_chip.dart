import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

/// A selectable day: the weekday above, the date below.
///
/// Straight from the booking widget's "2 / Dia" row:
///
/// ```html
/// <button style="display: flex; flex-direction: column; align-items: center;
///   gap: 2px; min-height: 62px; padding: 9px 0; border-radius: 16px;
///   transition: background-color 180ms linear;">
///   <span style="font-size: 11px; font-weight: 500;">Lun</span>
///   <span class="fig" style="font-size: 18px;">10</span>
/// </button>
/// ```
///
/// Note what it does NOT do: unlike [AppChip], it keeps its 16px radius when
/// selected. The board morphs a chip into a pill because a chip is a lozenge
/// either way; a two-line square becoming a pill would squash. The selection
/// is carried by the fill alone here, which is why the fill transition is the
/// one thing that has to be animated.
///
/// The date is an [AppFigure], so a row of days does not jitter between
/// single- and double-digit dates.
class AppDayChip extends StatelessWidget {
  const AppDayChip({
    super.key,
    required this.weekday,
    required this.day,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });

  /// Three letters, as the board writes them: `Lun`, `Mar`, `Mie`.
  final String weekday;

  /// Day of the month.
  final String day;

  final bool selected;

  /// A day with no slots left. Still shown — a gap in the row would make the
  /// user count dates to work out which day is missing.
  final bool disabled;

  final VoidCallback? onTap;

  /// `min-height: 62px`.
  static const double minHeight = 62;

  @override
  Widget build(BuildContext context) {
    final Color fill = disabled
        ? AppColors.field
        : (selected ? AppColors.blue : AppColors.surface);
    final Color border = selected ? AppColors.blue : AppColors.line;
    final Color dayInk = disabled
        ? AppColors.ink3
        : (selected ? AppColors.surface : AppColors.ink);
    final Color weekdayInk = disabled
        ? AppColors.ink3
        : (selected ? AppColors.blueSoft : AppColors.ink3);

    final Widget cell = AnimatedContainer(
      duration: AppMotion.tone,
      curve: Curves.linear,
      constraints: const BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadii.tileLgAll,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.xxs,
        children: <Widget>[
          Text(
            weekday,
            style: AppTypography.cap.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: weekdayInk,
            ),
          ),
          AppFigure(value: day, size: 18, color: dayInk),
        ],
      ),
    );

    if (disabled || onTap == null) {
      return Semantics(enabled: false, button: true, child: cell);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: '$weekday $day',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: cell,
      ),
    );
  }
}
