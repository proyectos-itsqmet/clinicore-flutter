import 'package:flutter/material.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';
import 'app_card.dart';

class PasswordRulesCard extends StatelessWidget {
  const PasswordRulesCard({super.key, required this.value});

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
          _Rule(
            label: 'Al menos un número',
            met: RegExp(r'\d').hasMatch(value),
          ),
        ],
      ),
    );
  }
}

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
