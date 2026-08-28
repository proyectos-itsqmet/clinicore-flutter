import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

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
  final Color? valueColor;
  final bool strikethrough;
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
