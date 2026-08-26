import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routes/app_path.dart';
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
///
/// ## The card is a summary; the record is a screen
///
/// Each row identifies its visit — specialty, date, doctor, sede, and the
/// diagnosis as one line — and opens [HistoryDetailScreen] for everything
/// else: hour, ticket number, the doctor's clinical notes, and the full
/// prescription with each medication's dose, frequency, duration and
/// instructions. Rendering all of that inline would cost the list the one job
/// it has, which is letting a patient FIND a visit among years of them: five
/// fully expanded visits is a page and a half of scrolling before the second
/// entry is even on screen.
///
/// The detail screen re-reads nothing — see its doc for why that matters
/// here specifically.
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
/// One recorded visit, as a row you can scan and tap.
///
/// It carries what IDENTIFIES the visit — specialty, date, doctor, sede — and
/// one line of the diagnosis, then hands the rest to [HistoryDetailScreen].
/// The pills say what is waiting behind the tap, so an entry with a
/// prescription is distinguishable from one without it before opening
/// anything.
///
/// It is tappable even when there is no encounter yet: the visit's own facts
/// — the hour, the ticket number, the service — are worth reading on their
/// own, and a row that refuses to open reads as broken rather than as empty.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final Appointment appointment = entry.appointment;
    final EncounterRecord? encounter = entry.encounter;
    final DateTime? when =
        encounter?.visitDate ?? appointment.finishedAt ?? appointment.date;

    // Every medication across every prescription for this visit. Counted
    // rather than listed: the count is what tells a patient there is a recipe
    // to open, and the detail is where it can be read correctly.
    final int medications = entry.prescriptions.fold<int>(
      0,
      (int total, PrescriptionRecord p) => total + p.items.length,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      onTap: () => context.push(AppPath.historyDetailScreen, extra: entry),
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
                        if (appointment.time != null) appointment.time!,
                        if (encounter?.doctorFullName != null)
                          encounter!.doctorFullName!
                        else if (appointment.doctorName != null)
                          appointment.doctorName!,
                      ].join(' / '),
                      style: AppTypography.cap,
                    ),
                  ],
                ),
              ),
              const Icon(
                AppIcons.chevronRight,
                size: 16,
                color: AppColors.ink3,
              ),
            ],
          ),

          // What is inside, before the tap. `Wrap` and not `Row`: a sede name
          // plus two pills overflows a phone's width, and a clipped pill
          // reads as a rendering bug.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (appointment.locationName != null)
                AppPill(label: appointment.locationName!, dense: true),
              if (medications > 0)
                AppPill(
                  label: medications == 1
                      ? '1 medicamento'
                      : '$medications medicamentos',
                  tone: AppPillTone.ok,
                  dense: true,
                ),
              if (encounter == null)
                const AppPill(
                  label: 'Sin resumen clinico',
                  tone: AppPillTone.plain,
                  dense: true,
                ),
            ],
          ),

          // The one clinical line worth putting in a list: it is what a
          // patient scans for when they are looking for a specific visit.
          // Capped at two lines — the whole text is one tap away, and a card
          // that grows with the doctor's typing breaks the rhythm of the
          // list.
          if (encounter != null) ...<Widget>[
            const AppHairline(),
            Text('Diagnostico', style: AppTypography.meta),
            Text(
              encounter.diagnosis,
              style: AppTypography.cap,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
