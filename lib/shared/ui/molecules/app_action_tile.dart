import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';
import 'app_card.dart';

/// The square shortcut tile from the mobile board's task rail — the 2x2 grid
/// of "Agenda tu cita / Mi historia / Resultados / Emergencia" directly under
/// the hero.
///
/// Geometry straight from `design/Mobile.dc.html`:
///
/// ```html
/// <a class="card" style="padding: 16px; min-height: 116px;
///    display: flex; flex-direction: column;
///    justify-content: space-between; gap: 10px;">
/// ```
///
/// `justify-content: space-between` is the part that matters: the icon pins
/// to the top and the label block to the bottom, so tiles with one-line and
/// two-line labels still line up across the row. Centring the column instead
/// makes the grid look subtly broken.
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

  /// The red 24/7 tile: emergency fill, white ink, and the icon tile flips to
  /// the white-at-20% treatment so it stays visible on red.
  final bool emergency;

  /// `min-height: 116px`.
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
                // The board overrides `.h3` to 16px inside these tiles — a
                // 19px heading in a 116px box would crowd the subtitle out.
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
                      // The emergency tile's subtitle is the phone number, and
                      // the board sets it bold because it is the payload.
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
