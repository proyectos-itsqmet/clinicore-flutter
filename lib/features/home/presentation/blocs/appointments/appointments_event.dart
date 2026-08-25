part of 'appointments_bloc.dart';

sealed class AppointmentsEvent extends Equatable {
  const AppointmentsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load, or reload, this bloc's scope.
///
/// There is no "change scope" event on purpose: the scope is fixed at
/// construction. See the bloc's doc for why.
class AppointmentsRequested extends AppointmentsEvent {
  const AppointmentsRequested();
}

/// Cancels one of the patient's own appointments.
///
/// [turnId] is the `Appointment.id` shown on the card — never a schedule id.
/// There is no confirmation step inside the bloc: the screen asks before
/// dispatching this, the same way `ProfileScreen` confirms before
/// [AuthSignOutRequested] — a destructive action is a UI concern, not a
/// state-machine one.
class AppointmentCancelRequested extends AppointmentsEvent {
  const AppointmentCancelRequested(this.turnId);

  final int turnId;

  @override
  List<Object?> get props => <Object?>[turnId];
}

/// A turn update arrived from the server in real time — see
/// `WatchTurnUpdates`.
///
/// [AppointmentsBloc] reacts by reloading this bloc's OWN scope rather than
/// patching [appointment] into `state.items` directly, for the same reason
/// `_onCancelRequested` reloads after a cancel: the updated turn may no
/// longer belong in THIS scope (a "waiting" turn just became "treated"),
/// and the rule for which statuses belong to which scope already lives in
/// one place — [AppointmentScope.statuses] — asking again reads it instead
/// of re-implementing it here.
class AppointmentRealtimeUpdateReceived extends AppointmentsEvent {
  const AppointmentRealtimeUpdateReceived(this.appointment);

  final Appointment appointment;

  @override
  List<Object?> get props => <Object?>[appointment];
}
