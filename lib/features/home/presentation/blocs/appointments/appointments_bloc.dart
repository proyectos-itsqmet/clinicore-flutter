import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/entities/appointment.dart';
import '../../../domain/repositories/appointments_repository.dart';
import '../../../domain/usecases/appointments_usecases.dart';

part 'appointments_event.dart';
part 'appointments_state.dart';

/// Owns one list of appointments.
///
/// ONE SCOPE PER INSTANCE, fixed at construction. "Mis citas" builds two of
/// them (upcoming and past) and "Historial" builds a third (attended only), so
/// switching the segmented control swaps which bloc the list reads from
/// instead of refetching.
///
/// That is the whole reason [scope] is a constructor argument and not an
/// event: a single bloc that reloaded on every tab change would refetch data
/// it already had every time the patient looked back and forth, and would show
/// a spinner each time.
///
/// Registered as a **factory** — one per screen, disposed with it. A singleton
/// would carry one patient's list into the next session on a shared phone.
class AppointmentsBloc extends Bloc<AppointmentsEvent, AppointmentsState> {
  AppointmentsBloc({required this.getMyAppointments, required this.scope})
    : super(const AppointmentsState.initial()) {
    on<AppointmentsRequested>(_onRequested);
  }

  final GetMyAppointments getMyAppointments;
  final AppointmentScope scope;

  Future<void> _onRequested(
    AppointmentsRequested event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(
      state.copyWith(status: AppointmentsStatus.loading, clearFailure: true),
    );

    final result = await getMyAppointments(
      GetMyAppointmentsParams(scope: scope),
    );

    emit(
      result.fold(
        (Failure failure) => state.copyWith(
          status: AppointmentsStatus.failure,
          failure: failure,
        ),
        (AppointmentPage page) => state.copyWith(
          status: AppointmentsStatus.ready,
          items: page.items,
          clearFailure: true,
        ),
      ),
    );
  }
}
