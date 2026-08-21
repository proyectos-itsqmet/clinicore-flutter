import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'app_glass.dart';

/// The tone of a pill. Each one is a measured foreground/background pair, not
/// a colour preference.
enum AppPillTone {
  /// Cool fill — the default pill everywhere (counts, prices, dates).
  tint,

  /// Translucent, for pills sitting over the dark hero photography.
  glass,

  /// Success / confirmation.
  ok,

  /// Warm band tone, matching the cream section.
  gold,

  /// Neutral surface with a hairline — secondary metadata.
  plain,
}

/// The label capsule: a short, non-interactive status or fact.
///
/// A pill is NOT a chip. A chip is a control the user picks; a pill is a
/// statement the app makes. If it responds to a tap it should be an
/// [AppChip] or an `AppButton`, not this.
///
/// Geometry from `design/Mobile.dc.html`'s `.pill`: `min-height: 44px;
/// padding: 9px 16px; gap: 7px; font-size: 14px; font-weight: 600` — and the
/// 44 is the platform touch-target floor, kept even though a pill is not
/// tappable so that pills and chips line up in a mixed row.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.tone = AppPillTone.tint,
    this.leading,
    this.dense = false,
  });

  final String label;
  final AppPillTone tone;

  /// An icon or an `AppLiveDot`, drawn before the label.
  final Widget? leading;

  /// The board's compact variant (`min-height: 32px; padding: 5px 12px;
  /// font-size: 13px`), used inside cards where a 44px pill would dominate.
  final bool dense;

  Color get _ink => switch (tone) {
    AppPillTone.tint => AppColors.blueText,
    AppPillTone.glass => AppColors.surface,
    AppPillTone.ok => AppColors.ok,
    AppPillTone.gold => AppColors.goldInk,
    AppPillTone.plain => AppColors.ink3,
  };

  Color? get _fill => switch (tone) {
    AppPillTone.tint => AppColors.tint,
    AppPillTone.glass => null, // AppGlass paints its own.
    AppPillTone.ok => AppColors.ok.withValues(alpha: 0.12),
    AppPillTone.gold => AppColors.cream,
    AppPillTone.plain => AppColors.surface,
  };

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: <Widget>[
          if (leading != null)
            IconTheme.merge(
              data: IconThemeData(color: _ink, size: dense ? 14 : 16),
              child: leading!,
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.pill.copyWith(
                color: _ink,
                fontSize: dense ? 13 : 14,
              ),
            ),
          ),
        ],
      ),
    );

    final Widget sized = ConstrainedBox(
      constraints: BoxConstraints(minHeight: dense ? 32 : AppSpacing.touchMin),
      child: content,
    );

    if (tone == AppPillTone.glass) {
      return AppGlass(child: sized);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: AppRadii.pillAll,
        border: tone == AppPillTone.plain
            ? Border.all(color: AppColors.line)
            : null,
      ),
      child: sized,
    );
  }
}
