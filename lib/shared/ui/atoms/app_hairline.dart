import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The 1px rule the boards use inside cards to separate two groups of facts:
/// `<span style="height: 1px; background-color: #E4DCD2"></span>`.
///
/// Not a Material [Divider]. Divider reserves 16px of vertical space by
/// default and centres the line inside it, so it fights the explicit `gap`
/// the surrounding column already declares. This draws exactly one physical
/// pixel and occupies exactly that.
///
/// ## `width: double.infinity` is not decoration
///
/// A [ColoredBox] with no child has NO intrinsic width, so under loose
/// horizontal constraints it sizes to zero and this widget renders 1px tall by
/// 0px wide — present in the tree, taking its 1px of height, and completely
/// invisible. That is what happens inside any [Column] left on its default
/// `CrossAxisAlignment.center`, which is the common case and gives no warning.
///
/// Asking for infinite width makes the line adopt whatever width its parent
/// offers, so it draws correctly whether the parent stretches it or not. The
/// one context this cannot serve is an unbounded one — a [Row] without
/// [Expanded], a horizontal scroll view — and a full-width rule inside those
/// has no defined width to take anyway.
class AppHairline extends StatelessWidget {
  const AppHairline({super.key, this.color = AppColors.line});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: ColoredBox(color: color),
    );
  }
}
