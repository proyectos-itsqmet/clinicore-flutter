import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/appointment.dart';

/// Which slice of the patient's appointments a screen is asking for.
///
/// The three cases exist because the two tabs and the history screen ask
/// different questions, and each maps to a different set of wire statuses:
///
/// * [upcoming] — "when do I have to be there?"
/// * [past] — "when was I last seen?"
/// * [attended] — history: only visits that actually happened. A cancelled
///   turn belongs in "Pasadas" but NOT in a medical history; listing it there
///   would suggest a consultation took place.
enum AppointmentScope {
  upcoming,
  past,
  attended;

  List<TurnStatus> get statuses => switch (this) {
    AppointmentScope.upcoming => const <TurnStatus>[
      TurnStatus.pending,
      TurnStatus.waiting,
      TurnStatus.inTreatment,
    ],
    AppointmentScope.past => const <TurnStatus>[
      TurnStatus.treated,
      TurnStatus.cancelled,
    ],
    AppointmentScope.attended => const <TurnStatus>[TurnStatus.treated],
  };

  /// Upcoming reads soonest-first; the past reads most-recent-first.
  bool get ascending => this == AppointmentScope.upcoming;
}

abstract interface class AppointmentsRepository {
  Future<Either<Failure, AppointmentPage>> getMyAppointments({
    required AppointmentScope scope,
    int page = 0,
    int size = 20,
  });

  /// Cancels one of the signed-in patient's own appointments.
  ///
  /// Takes the TURN id, never a schedule id. The server re-checks ownership
  /// itself — this is not the client's guarantee to make — and refuses a
  /// turn already attended or cancelled.
  Future<Either<Failure, Appointment>> cancelAppointment(int turnId);

  /// A live feed of the signed-in patient's OWN turn changes, pushed by the
  /// server the moment one of their turns is created, checked in, called,
  /// treated, cancelled or reassigned.
  ///
  /// Deliberately **not** `Future<Either<Failure, Stream<Appointment>>>` or
  /// anything that can fold into a failure: this is a best-effort layer ON
  /// TOP OF [getMyAppointments], never a replacement for it. A dropped
  /// connection emits nothing rather than an error — [getMyAppointments]
  /// already has, and keeps, the last good list, and a missed push is
  /// corrected by the next reconnect or the next manual reload. See
  /// `TurnUpdatesRemoteDataSource` for how the connection itself recovers.
  Stream<Appointment> watchTurnUpdates();
}
