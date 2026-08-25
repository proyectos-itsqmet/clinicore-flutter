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
import '../../domain/entities/clinical_record.dart';
import '../../domain/entities/history_entry.dart';
import '../blocs/history/history_bloc.dart';

/// The "Historial" tab — the clinical record.
///
/// Grouped by year, newest first, because that is how a person looks for a
/// past consultation ("that was the year of the surgery"). Within a year the
/// entries stay in reverse date order, which is what
/// [AppointmentScope.attended] already sorts them into — see [HistoryBloc].
///
/// ## Only ATTENDED visits, never cancelled ones
///
/// The scope behind [HistoryBloc.getMyAppointments] is
/// [AppointmentScope.attended], not `past`. A cancelled turn belongs in
/// "Mis citas → Pasadas" but has no place in a medical history: listing it
/// there suggests a consultation happened.
///
/// ## Every visit shows up; not every visit has a summary yet
///
/// A visit's diagnosis and prescriptions come from a SEPARATE server action
/// (`POST /api/encounters`, taken by the treating doctor after marking the
/// turn attended). A turn attended before this existed — or simply not yet
/// documented — has no matching [EncounterRecord]: [HistoryBloc] still shows
/// it, with only what a turn itself carries (date, specialty, doctor,
/// location), because a visit the clinic recorded is still a visit even
/// before someone writes it up.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HistoryBloc>(
      create: (_) => sl<HistoryBloc>()..add(const HistoryRequested()),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  /// Drives the pull-to-refresh gesture: fires a reload and waits for it to
  /// settle, so the spinner stays up for exactly as long as the request
  /// does. This — and the one-shot fetch in [HistoryScreen.build] — are the
  /// ONLY two triggers that ever call [HistoryRequested]: reading clinical
  /// data is audited server-side, so refetching on every rebuild would
  /// flood that log with reads nobody asked for.
  Future<void> _refresh(BuildContext context) {
    final HistoryBloc bloc = context.read<HistoryBloc>();
    final Future<HistoryState> settled = bloc.stream.firstWhere(
      (HistoryState state) => state.status != HistoryStatus.loading,
    );
    bloc.add(const HistoryRequested());
    return settled;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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

              BlocConsumer<HistoryBloc, HistoryState>(
                listenWhen: (HistoryState previous, HistoryState current) =>
                    current.isSessionExpired && !previous.isSessionExpired,
                listener: (BuildContext context, HistoryState state) {
                  context.read<AuthBloc>().add(const AuthSessionExpired());
                },
                builder: (BuildContext context, HistoryState state) {
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

                  if (state.status == HistoryStatus.failure &&
                      state.entries.isEmpty) {
                    return _HistoryFailure(
                      message:
                          state.failure?.message ??
                          'No pudimos cargar tu historial.',
                      onRetry: () => context.read<HistoryBloc>().add(
                        const HistoryRequested(),
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
                      // A background reload failed but there is still a list
                      // from before this attempt — see
                      // `HistoryState.isReloadFailure`. The list stays up;
                      // this is the only thing that changes.
                      if (state.isReloadFailure)
                        Text(
                          state.failure?.message ??
                              'No pudimos actualizar tu historial.',
                          style: AppTypography.cap.copyWith(
                            color: AppColors.emergency,
                          ),
                        ),

                      for (final _Year group in _groupByYear(state.entries))
                        ...<Widget>[
                          AppKicker(text: group.year, size: 11),
                          for (final HistoryEntry entry in group.entries)
                            _EntryCard(entry: entry),
                        ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Buckets by calendar year, preserving the order the list arrived in.
  ///
  /// [HistoryBloc] already sorts newest-first for this scope, so walking the
  /// list once and starting a new bucket on each year change is enough — no
  /// second sort, and no chance of the group order disagreeing with the entry
  /// order inside it.
  ///
  /// Entries with no date land in their own trailing group rather than being
  /// dropped: a visit the clinic recorded is still a visit, and the sort
  /// already sank them to the bottom.
  List<_Year> _groupByYear(List<HistoryEntry> items) {
    final List<_Year> groups = <_Year>[];

    for (final HistoryEntry item in items) {
      final String year =
          item.appointment.date?.year.toString() ?? 'Sin fecha';
      if (groups.isEmpty || groups.last.year != year) {
        groups.add(_Year(year: year, entries: <HistoryEntry>[item]));
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
  final List<HistoryEntry> entries;
}

/// One recorded visit, enriched with its clinical summary when there is one.
///
/// Still no `onTap` and no chevron: the summary and the prescription render
/// INLINE on the card now that the data exists, so there is nothing a tap
/// would open that is not already on screen.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final Appointment appointment = entry.appointment;
    final EncounterRecord? encounter = entry.encounter;
    final DateTime? when = appointment.finishedAt ?? appointment.date;

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
                      appointment.speciality ??
                          appointment.serviceName ??
                          'Consulta',
                      style: AppTypography.h3.copyWith(fontSize: 17),
                    ),
                    Text(
                      <String>[
                        if (when != null) shortDate(when),
                        if (appointment.doctorName != null)
                          appointment.doctorName!,
                      ].join(' / '),
                      style: AppTypography.cap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appointment.locationName != null)
            AppPill(label: appointment.locationName!, dense: true),

          // The clinical summary — absent for a visit nobody has documented
          // yet, which is expected, not an error. See the screen's doc.
          if (encounter != null) ...<Widget>[
            const AppHairline(),
            AppSummaryRow(label: 'Motivo', value: encounter.reasonForVisit),
            AppSummaryRow(label: 'Diagnostico', value: encounter.diagnosis),
          ],

          // Every medication gets its OWN row with its OWN dosage —
          // collapsing a prescription into one paragraph loses exactly the
          // detail a patient needs to take the drug correctly.
          if (entry.prescriptions.isNotEmpty) ...<Widget>[
            const AppHairline(),
            const AppKicker(text: 'Receta digital', size: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: <Widget>[
                for (final PrescriptionRecord prescription
                    in entry.prescriptions)
                  for (final PrescriptionItemEntry item in prescription.items)
                    _PrescriptionItemRow(item: item),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One medication line: what it is, how much, how often, for how long — and
/// the instructions when the doctor left any.
class _PrescriptionItemRow extends StatelessWidget {
  const _PrescriptionItemRow({required this.item});

  final PrescriptionItemEntry item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xxs,
      children: <Widget>[
        Row(
          spacing: AppSpacing.sm,
          children: <Widget>[
            const Icon(
              AppIcons.prescription,
              size: 14,
              color: AppColors.ink3,
            ),
            Expanded(
              child: Text(
                item.medication,
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Text(
          '${item.dosage} / ${item.frequency} / ${item.duration}',
          style: AppTypography.cap,
        ),
        if (item.instructions != null)
          Text(item.instructions!, style: AppTypography.cap),
      ],
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
