import 'package:flutter/material.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';
import 'app_card.dart';

/// A navigation row: icon, label, optional supporting line, chevron.
///
/// This is the profile screen's vocabulary — "Mi informacion", "Terminos y
/// condiciones", "Politica de privacidad". It composes [AppCard] rather than
/// drawing its own box, so the signature corner and the elevation come from
/// one place.
///
/// The affordances come from `design/panel-admin/Movil.dc.html`'s `.nav-row`,
/// which is the only navigation list the boards actually draw: a leading
/// glyph, a label that takes the remaining width, and a right chevron
/// (`M9 6l6 6-6 6`) at 15px in `ink-3`. What is NOT borrowed from it is the
/// height — that row is 44px because it lives in a cramped drawer with twelve
/// siblings, whereas these rows are the screen's main content and get the
/// standard card padding.
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

  /// Optional — a row can be text-only (the terms screen's inner links).
  final IconData? icon;

  /// The second line, in `cap`. Keep it short; it is context, not a summary.
  final String? supporting;

  final VoidCallback? onTap;

  /// Replaces the chevron — a pill for a count, a switch, a value.
  final Widget? trailing;

  final AppIconTileTone tone;

  /// Destructive rows ("Cerrar sesion", "Eliminar cuenta"): the label and
  /// glyph take the emergency red. The fill stays white — a whole red card
  /// would read as an alert, not as an action.
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
