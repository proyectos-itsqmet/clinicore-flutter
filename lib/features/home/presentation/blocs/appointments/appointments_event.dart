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
