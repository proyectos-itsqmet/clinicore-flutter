import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

class AppDayChip extends StatelessWidget {
  const AppDayChip({
    super.key,
    required this.weekday,
    required this.day,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });

  final String weekday;
  final String day;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
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
