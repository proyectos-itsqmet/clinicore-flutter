import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../../shared/ui/organisms/organisms.dart';
import '../../domain/entities/patient_profile.dart';
import '../blocs/profile/profile_bloc.dart';
import '../widgets/contact_edit_sheet.dart';
import '../widgets/profile_scope.dart';

/// "Mi informacion" — the patient's own data, read-only by default.
///
/// Three groups, and the split between them is the point:
///
/// * **Identidad** is locked, and not because the UI decided so:
///   `PatientService.updatePatient` on the server ignores those fields. Name,
///   cedula and date of birth are what the medical history is filed under, and
///   a patient editing them in an app would silently orphan their own record.
///   The screen says why instead of just greying the fields out — a disabled
///   field with no explanation reads as a bug.
/// * **Contacto** is editable, because the clinic needs it correct and the
///   patient is the only one who knows when it changed. The footer button
///   opens [ContactEditSheet].
/// * **Cobertura** has NO DATA and says so. The tables it needs — `insurers`,
///   `coverage_plans`, `patient_coverage` — do not exist on the server. It used
///   to render invented values under a "Datos de ejemplo" label; now that the
///   two groups above it are real, that label would no longer tell a patient
///   which half was made up.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScope(child: _PersonalInfoView());
  }
}

class _PersonalInfoView extends StatelessWidget {
  const _PersonalInfoView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (ProfileState previous, ProfileState current) =>
          previous.status != current.status &&
          current.status == ProfileStatus.saved,
      listener: (BuildContext context, ProfileState state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos de contacto actualizados.')),
        );
      },
      builder: (BuildContext context, ProfileState state) {
        final PatientProfile? profile = state.profile;

        return AppScreen(
          topBar: AppTopBar(
            title: 'Mi informacion',
            onBack: () => Navigator.of(context).pop(),
          ),
          // The button is only offered once there is something to edit.
          // Opening an empty form and posting it would wipe the patient's
          // contact data with blanks.
          footer: profile == null
              ? null
              : AppButton(
                  label: 'Editar datos de contacto',
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  leading: const Icon(AppIcons.person),
                  onPressed: state.isBusy
                      ? null
                      : () => ContactEditSheet.show(context, profile),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.section,
            children: <Widget>[
              const SizedBox(height: AppSpacing.section),

              if (profile == null)
                ..._loadingOrError(context, state)
              else ...<Widget>[
                _Group(
                  kicker: 'Identidad',
                  note:
                      'Estos datos no se pueden cambiar desde la app: tu '
                      'historia clinica esta archivada con ellos. Si hay un '
                      'error, avisanos en recepcion con tu cedula.',
                  rows: <AppSummaryRow>[
                    AppSummaryRow(label: 'Nombre', value: profile.fullName),
                    AppSummaryRow(label: 'Cedula', value: profile.cedula),
                    AppSummaryRow(
                      label: 'Fecha de nacimiento',
                      value: profile.birthday == null
                          ? _missing
                          : longDate(profile.birthday!),
                    ),
                    AppSummaryRow(
                      label: 'Sexo',
                      // An unrecognised enum yields an empty label — showing
                      // the raw `GENDER_X` would leak the wire format onto a
                      // patient's screen.
                      value: profile.gender.label.isEmpty
                          ? _missing
                          : profile.gender.label,
                    ),
                  ],
                ),

                _Group(
                  kicker: 'Contacto',
                  rows: <AppSummaryRow>[
                    AppSummaryRow(label: 'Correo', value: profile.email),
                    AppSummaryRow(
                      label: 'Celular',
                      value: profile.phone ?? _missing,
                    ),
                    AppSummaryRow(
                      label: 'Direccion',
                      value: profile.address ?? _missing,
                    ),
                    AppSummaryRow(
                      label: 'Contacto de emergencia',
                      value: profile.emergencyContact ?? _missing,
                    ),
                  ],
                ),

                // Not a group of empty rows: a card with three "Sin
                // registrar" lines looks like data the clinic lost. This says
                // the feature is not built, which is what is true.
                const _CoverageNotice(),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Shown while the first load runs, or when it failed with nothing cached.
  List<Widget> _loadingOrError(BuildContext context, ProfileState state) {
    if (state.status == ProfileStatus.failure) {
      return <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: <Widget>[
              Text(
                state.failure?.message ?? 'No pudimos cargar tu informacion.',
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
              AppButton(
                label: 'Reintentar',
                variant: AppButtonVariant.ghost,
                onPressed: () =>
                    context.read<ProfileBloc>().add(const ProfileRequested()),
              ),
            ],
          ),
        ),
      ];
    }

    // Reserves the geometry of the two real groups: a 4-row card each.
    return const <Widget>[
      AppSkeleton.card(height: 220),
      AppSkeleton.card(height: 196),
    ];
  }

  /// What an unset optional field reads as. Not an empty string: a blank value
  /// next to a label looks like a rendering bug.
  static const String _missing = 'Sin registrar';
}

/// Says what Cobertura is, and that it is not available.
class _CoverageNotice extends StatelessWidget {
  const _CoverageNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        const AppKicker(text: 'Cobertura', size: 11),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: <Widget>[
              const Icon(AppIcons.info, size: 16, color: AppColors.ink3),
              Expanded(
                child: Text(
                  'Tu aseguradora y tu plan todavia no estan disponibles en '
                  'la app. Consultalos en recepcion con tu cedula.',
                  style: AppTypography.cap,
                ),
              ),
            ],
          ),
        ),
      ],
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
