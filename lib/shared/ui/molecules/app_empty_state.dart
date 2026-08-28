import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pad,
          vertical: AppSpacing.sectionY,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: AppSpacing.xxl,
          children: <Widget>[
            AppIconTile(icon: icon, size: 64, radius: AppRadii.panelSm),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            Text(
              message,
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null)
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.ghost,
              ),
          ],
        ),
      ),
    );
  }
}
