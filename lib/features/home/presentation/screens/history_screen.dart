import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../blocs/appointments/appointments_bloc.dart';

/// The "Historial" tab — the clinical record.
///
/// Grouped by year, newest first, because that is how a person looks for a
/// past consultation ("that was the year of the surgery"). Within a year the
/// entries stay in reverse date order, which is what
/// [AppointmentScope.attended] already sorts them into.
///
/// ## Only ATTENDED visits, never cancelled ones
///
/// The scope is [AppointmentScope.attended], not `past`. A cancelled turn
/// belongs in "Mis citas → Pasadas" but has no place in a medical history:
/// listing it there suggests a consultation happened.
///
/// ## What this screen deliberately does NOT show
///
/// The board draws each entry with a diagnosis summary and output pills —
/// "Receta digital", "Laboratorio", "Certificado". **None of that data
/// exists.** It needs `encounters` and `prescriptions` + `prescription_items`
/// on the server, and those tables were not built.
///
/// So the entries show what is real — date, specialty, doctor, location — and
/// the screen says once, at the bottom, that the clinical detail is not
/// available yet. The alternative was keeping the invented summaries with a
/// "Datos de ejemplo" label under a list that is now REAL, which is the worst
/// of both: a patient cannot tell which half was made up.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppointmentsBloc>(
      create: (_) => sl<AppointmentsBloc>(param1: AppointmentScope.attended)
        ..add(const AppointmentsRequested()),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.pad,
          right: AppSpacing.pad,
          top: AppSpacing.sectionY * 0.5,
          bottom: AppSpacing.sectionY * 0.5 + context.bottomSafeInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.section,
          children: <Widget>[
            const AppSectionHeading(
              kicker: 'Tu historia',
              title: 'Historial clinico.',
              lead: 'Todo lo que paso, en un solo lugar y siempre contigo.',
            ),

            BlocConsumer<AppointmentsBloc, AppointmentsState>(
              listenWhen: (
                AppointmentsState previous,
                AppointmentsState current,
              ) => current.isSessionExpired && !previous.isSessionExpired,
              listener: (BuildContext context, AppointmentsState state) {
                context.read<AuthBloc>().add(const AuthSessionExpired());
              },
              builder: (BuildContext context, AppointmentsState state) {
                if (state.isFirstLoad) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.section,
                    children: <Widget>[
                      AppSkeleton.card(height: 92),
                      AppSkeleton.card(height: 92),
                    ],
                  );
                }

                if (state.status == AppointmentsStatus.failure) {
                  return _HistoryFailure(
                    message:
                        state.failure?.message ??
                        'No pudimos cargar tu historial.',
                    onRetry: () => context.read<AppointmentsBloc>().add(
                      const AppointmentsRequested(),
                    ),
                  );
                }

                if (state.isEmpty) {
                  return const AppEmptyState(
                    icon: AppIcons.history,
                    title: 'Tu historial esta vacio',
                    message:
                        'Despues de tu primera consulta vas a encontrar aca '
                        'las visitas que registro la clinica.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.section,
                  children: <Widget>[
                    for (final _Year group in _groupByYear(state.items))
                      ...<Widget>[
                        AppKicker(text: group.year, size: 11),
                        for (final Appointment entry in group.entries)
                          _EntryCard(entry: entry),
                      ],

                    // Said ONCE, at the bottom, and about the thing that is
                    // genuinely missing — not a blanket "datos de ejemplo"
                    // over a list that is now real.
                    Text(
                      'El resumen de cada consulta y sus recetas todavia no '
                      'estan disponibles en la app. Pedilos en recepcion con '
                      'tu cedula.',
                      style: AppTypography.cap,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Buckets by calendar year, preserving the order the list arrived in.
  ///
  /// The repository already sorted newest-first for this scope, so walking the
  /// list once and starting a new bucket on each year change is enough — no
  /// second sort, and no chance of the group order disagreeing with the entry
  /// order inside it.
  ///
  /// Entries with no date land in their own trailing group rather than being
  /// dropped: a visit the clinic recorded is still a visit, and the sort
  /// already sank them to the bottom.
  List<_Year> _groupByYear(List<Appointment> items) {
    final List<_Year> groups = <_Year>[];

    for (final Appointment item in items) {
      final String year = item.date?.year.toString() ?? 'Sin fecha';
      if (groups.isEmpty || groups.last.year != year) {
        groups.add(_Year(year: year, entries: <Appointment>[item]));
      } else {
        groups.last.entries.add(item);
      }
    }

    return groups;
  }
}

class _Year {
  _Year({required this.year, required this.entries});

  final String year;
  final List<Appointment> entries;
}

/// One recorded visit.
///
/// No `onTap` and no chevron. The board draws both because tapping an entry
/// opens its detail — the diagnosis, the prescription, the lab result — and
/// there is nothing to open: that data has no table. A chevron that leads
/// nowhere is a promise the app cannot keep.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final Appointment entry;

  @override
  Widget build(BuildContext context) {
    final DateTime? when = entry.finishedAt ?? entry.date;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: <Widget>[
          Row(
            spacing: AppSpacing.lg,
            children: <Widget>[
              const AppIconTile(icon: AppIcons.specialty, size: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: <Widget>[
                    Text(
                      entry.speciality ?? entry.serviceName ?? 'Consulta',
                      style: AppTypography.h3.copyWith(fontSize: 17),
                    ),
                    Text(
                      <String>[
                        if (when != null) shortDate(when),
                        if (entry.doctorName != null) entry.doctorName!,
                      ].join(' / '),
                      style: AppTypography.cap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entry.locationName != null)
            AppPill(label: entry.locationName!, dense: true),
        ],
      ),
    );
  }
}

class _HistoryFailure extends StatelessWidget {
  const _HistoryFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: <Widget>[
          Text(message, style: AppTypography.body, textAlign: TextAlign.center),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.ghost,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
