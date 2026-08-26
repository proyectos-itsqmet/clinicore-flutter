import 'package:flutter/material.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';
import 'app_card.dart';

/// The live password checklist: the rules stated up front, ticking themselves
/// as the user types.
///
/// The rules are shown BEFORE they are broken rather than as an error
/// afterwards. Same information, opposite feeling — and it is the difference
/// between a form that helps and a form that scolds.
///
/// ## Why this is one widget and not two copies
///
/// Two screens set a password: the last step of recovery, and "Cambiar
/// contrasena" inside the account. They must agree, and not approximately —
/// a checklist that ticks green while `Validators.password` still rejects the
/// value is a form the patient cannot get out of, with no visible reason.
/// Keeping the predicates in one place is what makes that impossible.
///
/// ## The rules mirror `Validators.password`
///
/// Eight characters, at least one letter, at least one digit — deliberately
/// no symbol requirement and no maximum. NIST dropped composition rules years
/// ago because they push people toward `Passw0rd!` and away from length,
/// which is the thing that actually helps. If that validator changes, this
/// list changes with it or the two start lying to each other.
class PasswordRulesCard extends StatelessWidget {
  const PasswordRulesCard({super.key, required this.value});

  /// What is currently typed. Not a controller: this widget only reads, and
  /// taking the raw string keeps it out of the business of when to rebuild —
  /// that belongs to whoever owns the field.
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: <Widget>[
          const AppKicker(text: 'Debe tener', size: 11),
          _Rule(label: 'Al menos 8 caracteres', met: value.length >= 8),
          _Rule(
            label: 'Al menos una letra',
            met: RegExp(r'[A-Za-z]').hasMatch(value),
          ),
          _Rule(label: 'Al menos un numero', met: RegExp(r'\d').hasMatch(value)),
        ],
      ),
    );
  }
}

/// One line of the checklist. Met rules go `ok` green with a check; unmet ones
/// stay `ink-3` with a hollow marker — never red, because a rule the user has
/// not reached yet is not an error.
class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: <Widget>[
        AnimatedContainer(
          duration: AppMotion.tone,
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? AppColors.ok : Colors.transparent,
            border: met ? null : Border.all(color: AppColors.line, width: 1.5),
          ),
          child: met
              ? const Icon(AppIcons.success, size: 12, color: AppColors.surface)
              : null,
        ),
        Expanded(
          child: Text(
            label,
            style: AppTypography.cap.copyWith(
              color: met ? AppColors.ok : AppColors.ink3,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
