import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// One destination in [AppBottomNav].
@immutable
class AppNavItem {
  const AppNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The app's bottom navigation bar.
///
/// The design boards have no bottom navigation — the web app is a landing
/// page, not a tabbed app — so this is **derived**, and it is derived from the
/// one piece of bottom chrome the mobile board does draw: `.actionbar`.
///
/// ```css
/// .actionbar {
///   position: absolute; left: 0; right: 0; bottom: 0;
///   padding: 12px 16px 14px;
///   background-color: rgb(255 255 255 / .92);
///   backdrop-filter: blur(16px);
///   border-top: 1px solid var(--line);
/// }
/// ```
///
/// Everything structural comes from there: the translucent white ground, the
/// 16px blur behind it, the single hairline on top, and the asymmetric
/// vertical padding (12 above, 14 below — the extra 2px reads as optical
/// centring once the labels are in).
///
/// The **active treatment** is the part with no direct source, so it borrows
/// the system's existing "this one is active" language rather than inventing
/// a third: a `tint` pill behind the glyph. That is exactly what
/// `panel-admin/Movil.dc.html` does for its selected nav row, and it is the
/// same tint/surface relationship the segmented control's thumb uses,
/// inverted. An underline or a dot would have been a new idea; this is not.
///
/// Note the blur conversion, same as [AppGlass]: CSS `blur(16px)` is roughly
/// 2 sigma, so Flutter wants 8.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// `background-color: rgb(255 255 255 / .92)`.
  static const double _groundAlpha = 0.92;

  /// `backdrop-filter: blur(16px)` expressed as a Gaussian sigma.
  static const double _blurSigma = 8;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: _groundAlpha),
            border: const Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Padding(
            // `padding: 12px 16px 14px`, plus the system gesture inset so the
            // bar never sits under the home indicator.
            padding: EdgeInsets.only(
              top: AppSpacing.lg,
              left: AppSpacing.padChrome,
              right: AppSpacing.padChrome,
              bottom: AppSpacing.xl + context.bottomSafeInset,
            ),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = selected ? AppColors.blueText : AppColors.ink3;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: <Widget>[
            AnimatedContainer(
              duration: AppMotion.tone,
              curve: AppMotion.easeBrand,
              height: 32,
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.tint : Colors.transparent,
                borderRadius: AppRadii.pillAll,
              ),
              child: Icon(item.icon, size: 22, color: ink),
            ),
            AnimatedDefaultTextStyle(
              duration: AppMotion.tone,
              style: AppTypography.cap.copyWith(
                fontSize: 11,
                color: selected ? AppColors.ink : AppColors.ink3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
