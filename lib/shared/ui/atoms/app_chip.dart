import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// A selectable rectangular option — a doctor, a day, a time slot.
///
/// The behaviour worth protecting here is the **corner morph**: an unselected
/// chip is a 16px rounded rectangle, a selected one is a pill, and the board
/// animates between the two over 300ms on the brand curve
/// (`.chip { transition: ... border-radius 300ms var(--e) }`). That morph is
/// the selection feedback. Freezing the radius and only swapping the fill
/// would still "work", and it would still be wrong.
///
/// A disabled chip is a taken slot, not a broken control, which is why it
/// keeps its label and strikes it through rather than fading it out.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.disabled = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// A slot that exists but cannot be taken (the board strikes these
  /// through: "Los cupos tachados estan ocupados").
  final bool disabled;

  /// Fill the parent's width — for chips stacked in a column, as the booking
  /// widget's doctor list does.
  final bool expand;

  /// `.chip { min-height: 46px }`.
  static const double minHeight = 46;
  static const double _borderWidth = 1.5;

  Color get _fill {
    if (disabled) return AppColors.field;
    return selected ? AppColors.blue : AppColors.surface;
  }

  Color get _border {
    if (disabled) return AppColors.line;
    return selected ? AppColors.blue : AppColors.line;
  }

  Color get _ink {
    if (disabled) return AppColors.ink3;
    return selected ? AppColors.surface : AppColors.ink2;
  }

  @override
  Widget build(BuildContext context) {
    final Widget chip = AnimatedContainer(
      duration: AppMotion.morph,
      curve: AppMotion.easeBrand,
      constraints: const BoxConstraints(minHeight: minHeight),
      width: expand ? double.infinity : null,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: _fill,
        // The morph: 16px rounded rectangle -> pill.
        borderRadius: selected ? AppRadii.pillAll : AppRadii.tileLgAll,
        border: Border.all(color: _border, width: _borderWidth),
      ),
      child: AnimatedDefaultTextStyle(
        duration: AppMotion.tone,
        style: AppTypography.chip.copyWith(
          color: _ink,
          decoration: disabled ? TextDecoration.lineThrough : null,
          decorationColor: disabled ? AppColors.ink3 : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (disabled || onTap == null) {
      return Semantics(enabled: !disabled, button: true, child: chip);
    }

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}
