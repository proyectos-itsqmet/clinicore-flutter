import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// A label/value pair on one line, as the booking widget's summary panel
/// draws it:
///
/// ```html
/// <span style="display: flex; justify-content: space-between; gap: 12px">
///   <span class="meta">Medico</span>
///   <span class="meta" style="font-weight: 700; color: #13243F">...</span>
/// </span>
/// ```
///
/// The whole pattern is in that one override: label in `meta` (500 weight,
/// `ink-3`), value in `meta` at **700 weight and `ink`**. The value is what
/// the user came to read, and the weight is what says so. Rows where both
/// sides look the same read as a wall of text.
class AppSummaryRow extends StatelessWidget {
  const AppSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.strikethrough = false,
    this.emphasis,
  });

  final String label;
  final String value;

  /// For a value that carries a status: `ok` green for a confirmed price,
  /// `emergency` for a problem.
  final Color? valueColor;

  /// A superseded value — the list price next to the plan price. The board
  /// strikes it through and drops it to `ink-3`.
  final bool strikethrough;

  /// Replaces the text value with a widget — an `AppFigure` for the total,
  /// an `AppPill` for a state.
  final Widget? emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: AppSpacing.lg,
      children: <Widget>[
        Expanded(child: Text(label, style: AppTypography.meta)),
        if (emphasis != null)
          emphasis!
        else
          Text(
            value,
            style: AppTypography.meta.copyWith(
              fontWeight: strikethrough ? FontWeight.w500 : FontWeight.w700,
              color: strikethrough
                  ? AppColors.ink3
                  : (valueColor ?? AppColors.ink),
              decoration: strikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
      ],
    );
  }
}
