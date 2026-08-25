import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/appointment.dart';
import '../../../domain/entities/clinical_record.dart';
import '../../../domain/entities/history_entry.dart';
import '../../../domain/repositories/appointments_repository.dart';
import '../../../domain/usecases/appointments_usecases.dart';
import '../../../domain/usecases/clinical_usecases.dart';

part 'history_event.dart';
part 'history_state.dart';

/// Owns the "Historial" tab: attended visits, joined with whatever clinical
/// detail the server has documented for each one.
///
/// ## Three reads, one screen, and why they are not one call
///
/// `/api/turns/me`, `/api/encounters/me` and `/api/prescriptions/me` are
/// three independent server resources with no combined endpoint. This bloc
/// is where they meet: [getMyAppointments] gives the list of visits (scoped
/// to [AppointmentScope.attended], so a cancelled turn never appears here —
/// see that scope's own doc), [getMyEncounters] gives whichever of those
/// visits a doctor has documented, and [getMyPrescriptions] gives what was
/// prescribed during each one. [_merge] joins them by id —
/// `Appointment.id == EncounterRecord.turnId`, then
/// `EncounterRecord.id == PrescriptionRecord.encounterId`.
///
/// ## Appointments are load-bearing; clinical detail is not
///
/// If [getMyAppointments] fails, the whole screen fails — there is no visit
/// list to show. If [getMyEncounters] or [getMyPrescriptions] fails, the
/// visit list still renders; the entries it could not enrich simply carry no
/// clinical detail, the same as a visit nobody has documented yet. A patient
/// who cannot load today's diagnosis must still be able to see that the
/// visit happened.
///
/// ## Fetching is deliberate, not automatic
///
/// Reading clinical data is AUDITED server-side — every one of these calls
/// writes a `ClinicalAccessLogService.record` row. [HistoryRequested] is
/// fired exactly twice in normal use: once when the screen is built, and once
/// per explicit pull-to-refresh (`_HistoryView`'s `RefreshIndicator`).
/// Nothing here re-fetches on a timer, on a rebuild, or in response to
/// anything else.
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc({
    required this.getMyAppointments,
    required this.getMyEncounters,
    required this.getMyPrescriptions,
  }) : super(const HistoryState.initial()) {
    on<HistoryRequested>(_onRequested);
  }

  final GetMyAppointments getMyAppointments;
  final GetMyEncounters getMyEncounters;
  final GetMyPrescriptions getMyPrescriptions;

  Future<void> _onRequested(
    HistoryRequested event,
    Emitter<HistoryState> emit,
  ) async {
    emit(state.copyWith(status: HistoryStatus.loading, clearFailure: true));

    // Started together, not chained: none of the three depends on another's
    // result, so awaiting them one at a time would only add latency.
    final Future<Either<Failure, AppointmentPage>> appointmentsFuture =
        getMyAppointments(
          const GetMyAppointmentsParams(scope: AppointmentScope.attended),
        );
    final Future<Either<Failure, List<EncounterRecord>>> encountersFuture =
        getMyEncounters(const NoParams());
    final Future<Either<Failure, List<PrescriptionRecord>>>
    prescriptionsFuture = getMyPrescriptions(const NoParams());

    final Either<Failure, AppointmentPage> appointmentsResult =
        await appointmentsFuture;

    await appointmentsResult.fold(
      (Failure failure) async {
        emit(state.copyWith(status: HistoryStatus.failure, failure: failure));
      },
      (AppointmentPage page) async {
        // See the class doc: a failure enriching the list must never fail
        // the list itself.
        final List<EncounterRecord> encounters = (await encountersFuture)
            .fold(
              (Failure _) => const <EncounterRecord>[],
              (List<EncounterRecord> value) => value,
            );
        final List<PrescriptionRecord> prescriptions =
            (await prescriptionsFuture).fold(
              (Failure _) => const <PrescriptionRecord>[],
              (List<PrescriptionRecord> value) => value,
            );

        emit(
          state.copyWith(
            status: HistoryStatus.ready,
            entries: _merge(page.items, encounters, prescriptions),
            clearFailure: true,
          ),
        );
      },
    );
  }

  /// Keeps [appointments]' own order — already newest-first for
  /// [AppointmentScope.attended], see `AppointmentsRepositoryImpl._sort` —
  /// rather than re-sorting by anything on the encounter or prescription
  /// side.
  List<HistoryEntry> _merge(
    List<Appointment> appointments,
    List<EncounterRecord> encounters,
    List<PrescriptionRecord> prescriptions,
  ) {
    return appointments.map((Appointment appointment) {
      EncounterRecord? encounter;
      for (final EncounterRecord candidate in encounters) {
        if (candidate.turnId == appointment.id) {
          encounter = candidate;
          break;
        }
      }

      final int? encounterId = encounter?.id;
      final List<PrescriptionRecord> forVisit = encounterId == null
          ? const <PrescriptionRecord>[]
          : prescriptions
                .where((PrescriptionRecord p) => p.encounterId == encounterId)
                .toList();

      return HistoryEntry(
        appointment: appointment,
        encounter: encounter,
        prescriptions: forVisit,
      );
    }).toList();
  }
}
