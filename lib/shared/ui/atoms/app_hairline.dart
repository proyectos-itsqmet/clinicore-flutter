import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The 1px rule the boards use inside cards to separate two groups of facts:
/// `<span style="height: 1px; background-color: #E4DCD2"></span>`.
///
/// Not a Material [Divider]. Divider reserves 16px of vertical space by
/// default and centres the line inside it, so it fights the explicit `gap`
/// the surrounding column already declares. This draws exactly one physical
/// pixel and occupies exactly that.
class AppHairline extends StatelessWidget {
  const AppHairline({super.key, this.color = AppColors.line});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 1, child: ColoredBox(color: color));
  }
}
