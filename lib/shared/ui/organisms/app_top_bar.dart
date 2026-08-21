import 'package:flutter/material.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

/// The header for a screen you can go back from — "Mi informacion",
/// "Terminos y condiciones", the auth sub-steps.
///
/// This is NOT a Material [AppBar]. It draws the boards' vocabulary instead:
/// the page's own `field` ground rather than a raised surface, a 1px `line`
/// hairline instead of an elevation shadow, and `h3` for the title rather
/// than Material's `titleLarge`. An AppBar would arrive with a scroll-under
/// tint and a centred title on iOS, both of which the design does not have.
///
/// The back affordance is a 44x44 target — the floor every interactive
/// element in the boards respects.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.showHairline = true,
  });

  final String title;

  /// Null hides the back button — for a root screen that still wants a title.
  final VoidCallback? onBack;

  final Widget? trailing;

  /// Off for a screen whose first element already draws its own edge.
  final bool showHairline;

  static const double _height = 56;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.field,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: _height,
              child: Row(
                children: <Widget>[
                  if (onBack != null)
                    Semantics(
                      button: true,
                      label: 'Volver',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onBack,
                        child: const SizedBox.square(
                          dimension: AppSpacing.touchMin,
                          child: Center(
                            child: Icon(
                              AppIcons.chevronLeft,
                              size: 20,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: AppSpacing.pad),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: onBack != null ? AppSpacing.xs : 0,
                        right: AppSpacing.lg,
                      ),
                      child: Text(
                        title,
                        style: AppTypography.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.padChrome,
                      ),
                      child: trailing,
                    ),
                ],
              ),
            ),
            if (showHairline) const AppHairline(),
          ],
        ),
      ),
    );
  }
}
