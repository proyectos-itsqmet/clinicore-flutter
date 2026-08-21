import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

/// The "nothing here yet" panel.
///
/// Three tabs of this app can legitimately be empty on a brand-new account —
/// Mis citas, Historial, and Agendar before a selection — and an empty tab
/// that just shows blank field colour reads as a failed load. So the empty
/// state is a first-class molecule, not an afterthought.
///
/// It is built out of existing atoms (icon tile, h3, body, button) rather than
/// new illustration: the design system has no illustration vocabulary, and
/// inventing one here would be the single largest visual departure in the
/// whole port.
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

  /// The way out. An empty state with no action is a dead end — if there is
  /// genuinely nothing the user can do, say why in [message] instead.
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
