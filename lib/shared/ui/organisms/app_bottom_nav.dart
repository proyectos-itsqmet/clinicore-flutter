import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

@immutable
class AppNavItem {
  const AppNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

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

  static const double _groundAlpha = 0.92;

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
