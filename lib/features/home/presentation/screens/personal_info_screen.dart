import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../../shared/ui/organisms/organisms.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../domain/entities/coverage.dart';
import '../../domain/entities/patient_profile.dart';
import '../blocs/coverage/coverage_bloc.dart';
import '../blocs/profile/profile_bloc.dart';
import '../widgets/contact_edit_sheet.dart';
import '../widgets/profile_scope.dart';

/// What an unset optional field reads as. Not an empty string: a blank value
/// next to a label looks like a rendering bug. Shared by [_PersonalInfoView]
/// and [_CoverageSection] — they read from two different blocs, but an
/// absent value should read the same way regardless of which one it came
/// from.
const String _missing = 'Sin registrar';

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
/// * **Cobertura** reads `GET /api/patient-coverages/me` through its own
///   [CoverageBloc] — a patient may hold several coverages over the years,
///   but the server guarantees at most one is active at a time, and this
///   screen never draws a lapsed one with the same weight as the current
///   one. See `_CoverageSection`.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileScope(
      child: BlocProvider<CoverageBloc>(
        create: (_) => sl<CoverageBloc>()..add(const CoverageRequested()),
        child: const _PersonalInfoView(),
      ),
    );
  }
}

class _PersonalInfoView extends StatelessWidget {
  const _PersonalInfoView();

  @override
  Widget build(BuildContext context) {
    // A session dying while this screen is open is [CoverageBloc]'s problem
    // to REPORT, never to solve — same rule `ProfileScope` already applies to
    // [ProfileBloc]. Both blocs forward independently: neither knows the
    // other exists.
    return BlocListener<CoverageBloc, CoverageState>(
      listenWhen: (CoverageState previous, CoverageState current) =>
          current.isSessionExpired && !previous.isSessionExpired,
      listener: (BuildContext context, CoverageState state) {
        context.read<AuthBloc>().add(const AuthSessionExpired());
      },
      child: BlocConsumer<ProfileBloc, ProfileState>(
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
              title: 'Mi información',
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
                        'historia clínica esta archivada con ellos. Si hay un '
                        'error, avísanos en recepción con tu cédula.',
                    rows: <AppSummaryRow>[
                      AppSummaryRow(label: 'Nombre', value: profile.fullName),
                      AppSummaryRow(label: 'Cédula', value: profile.cedula),
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
                        label: 'Dirección',
                        value: profile.address ?? _missing,
                      ),
                      AppSummaryRow(
                        label: 'Contacto de emergencia',
                        value: profile.emergencyContact ?? _missing,
                      ),
                    ],
                  ),

                  const _CoverageSection(),
                ],
              ],
            ),
          );
        },
      ),
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
}

/// The "Cobertura" group: the active policy in full, past ones as a muted
/// list, and an honest empty state when there is neither.
///
/// This is its own [BlocBuilder] rather than a branch inside
/// `_PersonalInfoView`'s `ProfileBloc` consumer: coverage and the identity
/// record load independently, on two different blocs, and a patient whose
/// profile loaded fine but whose coverage request is still in flight (or
/// failed) should see the two groups above render immediately rather than
/// wait on each other.
class _CoverageSection extends StatelessWidget {
  const _CoverageSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoverageBloc, CoverageState>(
      builder: (BuildContext context, CoverageState state) {
        if (state.isFirstLoad) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: <Widget>[
              AppKicker(text: 'Cobertura', size: 11),
              AppSkeleton.card(height: 140),
            ],
          );
        }

        if (state.status == CoverageStatus.failure && state.coverages.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: <Widget>[
              const AppKicker(text: 'Cobertura', size: 11),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.cardPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.lg,
                  children: <Widget>[
                    Text(
                      state.failure?.message ??
                          'No pudimos cargar tu cobertura.',
                      style: AppTypography.body,
                      textAlign: TextAlign.center,
                    ),
                    AppButton(
                      label: 'Reintentar',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.read<CoverageBloc>().add(
                        const CoverageRequested(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final CoverageRecord? active = state.active;

        if (active == null) {
          return const _NoCoverage();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.lg,
          children: <Widget>[
            const AppKicker(text: 'Cobertura', size: 11),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.cardPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.lg,
                children: <Widget>[
                  Row(
                    spacing: AppSpacing.md,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          active.insurerName,
                          style: AppTypography.h3.copyWith(fontSize: 16),
                        ),
                      ),
                      // The one visual cue that makes an active policy
                      // impossible to mistake for a lapsed one — see the
                      // class doc.
                      const AppPill(
                        label: 'Activa',
                        tone: AppPillTone.ok,
                        dense: true,
                      ),
                    ],
                  ),
                  const AppHairline(),
                  AppSummaryRow(label: 'Plan', value: active.planName),
                  AppSummaryRow(
                    label: 'Cobertura',
                    value: '${active.coveragePercentage}%',
                  ),
                  AppSummaryRow(
                    label: 'Poliza',
                    value: active.policyNumber,
                  ),
                  AppSummaryRow(
                    label: 'Vigente desde',
                    value: active.validFrom == null
                        ? _missing
                        : longDate(active.validFrom!),
                  ),
                ],
              ),
            ),

            // Past policies, deliberately smaller and muted: a patient
            // scanning this list must never confuse "Vencida" for "Activa".
            for (final CoverageRecord past in state.history)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.cardPad),
                child: Row(
                  spacing: AppSpacing.md,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.xxs,
                        children: <Widget>[
                          Text(
                            '${past.insurerName} - ${past.planName}',
                            style: AppTypography.meta,
                          ),
                          Text(
                            'Poliza ${past.policyNumber}',
                            style: AppTypography.cap,
                          ),
                        ],
                      ),
                    ),
                    const AppPill(
                      label: 'Vencida',
                      tone: AppPillTone.plain,
                      dense: true,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown when the request succeeded and the patient simply has no coverage
/// on file — a real, valid state, not a missing feature.
class _NoCoverage extends StatelessWidget {
  const _NoCoverage();

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
                  'Todavía no tienes una cobertura de seguro registrada. Si '
                  'cuentas con una aseguradora, avisa en recepción con tu '
                  'cédula para que la carguen.',
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
