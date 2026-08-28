import 'package:flutter/material.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.showHairline = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showHairline;
  static const double _height = 56;
  static const double _hairlineHeight = 1;

  @override
  Size get preferredSize =>
      Size.fromHeight(showHairline ? _height + _hairlineHeight : _height);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.field,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
