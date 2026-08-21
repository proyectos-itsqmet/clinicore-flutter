import 'package:flutter/material.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../../shared/ui/organisms/organisms.dart';

/// "Mi informacion" — the patient's own data, read-only by default.
///
/// Three groups, and the split between them is the point:
///
/// * **Identidad** is locked. Name, cedula and date of birth are what the
///   medical history is filed under, and a patient editing them in an app
///   would silently orphan their own record. The screen says why instead of
///   just greying the fields out — a disabled field with no explanation reads
///   as a bug.
/// * **Contacto** is editable, because the clinic needs it to be correct and
///   the patient is the only one who knows when it changes.
/// * **Cobertura** is informational: what the clinic has on file, so the
///   patient can tell them when it is wrong.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      topBar: AppTopBar(
        title: 'Mi informacion',
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: AppButton(
        label: 'Editar datos de contacto',
        size: AppButtonSize.lg,
        fullWidth: true,
        leading: const Icon(AppIcons.person),
        onPressed: () {},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.section,
        children: <Widget>[
          const SizedBox(height: AppSpacing.section),

          _Group(
            kicker: 'Identidad',
            note:
                'Estos datos no se pueden cambiar desde la app: tu '
                'historia clinica esta archivada con ellos. Si hay un error, '
                'avisanos en recepcion con tu cedula.',
            rows: <AppSummaryRow>[
              AppSummaryRow(label: 'Nombre', value: '[NOMBRE COMPLETO]'),
              AppSummaryRow(label: 'Cedula', value: '[CEDULA]'),
              AppSummaryRow(label: 'Fecha de nacimiento', value: '[FECHA]'),
              AppSummaryRow(label: 'Sexo', value: '[SEXO]'),
            ],
          ),

          _Group(
            kicker: 'Contacto',
            rows: <AppSummaryRow>[
              AppSummaryRow(label: 'Correo', value: '[CORREO]'),
              AppSummaryRow(label: 'Celular', value: '[CELULAR]'),
              AppSummaryRow(label: 'Direccion', value: '[DIRECCION]'),
              AppSummaryRow(
                label: 'Contacto de emergencia',
                value: '[NOMBRE / TELEFONO]',
              ),
            ],
          ),

          _Group(
            kicker: 'Cobertura',
            rows: <AppSummaryRow>[
              AppSummaryRow(label: 'Aseguradora', value: '[ASEGURADORA]'),
              AppSummaryRow(label: 'Plan', value: '[PLAN]'),
              AppSummaryRow(label: 'Numero de afiliado', value: '[NUMERO]'),
            ],
          ),

          Text('Datos de ejemplo.', style: AppTypography.cap),
        ],
      ),
    );
  }
}

/// A titled group of label/value rows inside one card.
class _Group extends StatelessWidget {
  const _Group({required this.kicker, required this.rows, this.note});

  final String kicker;
  final List<AppSummaryRow> rows;

  /// Explains a constraint. Rendered under a hairline so it reads as a note
  /// about the group rather than another row of data.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        AppKicker(text: kicker, size: 11),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: <Widget>[
              for (int i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0) const AppHairline(),
                rows[i],
              ],
              if (note != null) ...<Widget>[
                const AppHairline(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.md,
                  children: <Widget>[
                    const Icon(AppIcons.info, size: 16, color: AppColors.ink3),
                    Expanded(child: Text(note!, style: AppTypography.cap)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
