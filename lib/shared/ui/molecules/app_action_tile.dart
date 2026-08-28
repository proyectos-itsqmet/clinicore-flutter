import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';
import 'app_card.dart';

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.emergency = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool emergency;
  static const double minHeight = 116;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      tone: emergency ? AppCardTone.emergency : AppCardTone.surface,
      padding: const EdgeInsets.all(AppSpacing.cardPadSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: minHeight - AppSpacing.cardPadSm * 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: AppSpacing.md,
          children: <Widget>[
            AppIconTile(
              icon: icon,
              tone: emergency ? AppIconTileTone.onDark : AppIconTileTone.tint,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    fontSize: 16,
                    color: emergency ? AppColors.surface : AppColors.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.cap.copyWith(
                      color: emergency ? AppColors.surface : AppColors.ink3,
                      fontWeight: emergency ? FontWeight.w700 : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
