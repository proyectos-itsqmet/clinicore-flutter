import 'package:flutter/material.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';
import 'app_card.dart';

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.label,
    this.icon,
    this.supporting,
    this.onTap,
    this.trailing,
    this.tone = AppIconTileTone.tint,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final String? supporting;
  final VoidCallback? onTap;
  final Widget? trailing;
  final AppIconTileTone tone;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color labelColor = danger ? AppColors.emergency : AppColors.ink;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadSm,
        vertical: AppSpacing.xl,
      ),
      child: Row(
        spacing: AppSpacing.lg,
        children: <Widget>[
          if (icon != null)
            AppIconTile(
              icon: icon!,
              size: 42,
              radius: AppRadii.tileLg,
              tone: danger ? AppIconTileTone.tint : tone,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.h3.copyWith(
                    fontSize: 16,
                    color: labelColor,
                  ),
                ),
                if (supporting != null)
                  Text(supporting!, style: AppTypography.cap),
              ],
            ),
          ),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : const Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: AppColors.ink3,
                    )),
        ],
      ),
    );
  }
}
