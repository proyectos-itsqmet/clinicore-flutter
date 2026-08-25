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
  AppointmentsBloc({
    required this.getMyAppointments,
    required this.cancelAppointment,
    required this.scope,
  }) : super(const AppointmentsState.initial()) {
    on<AppointmentsRequested>(_onRequested);
    on<AppointmentCancelRequested>(_onCancelRequested);
  }

  final GetMyAppointments getMyAppointments;
  final CancelAppointment cancelAppointment;
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

  Future<void> _onCancelRequested(
    AppointmentCancelRequested event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(
      state.copyWith(
        cancellingId: event.turnId,
        clearCancelFailure: true,
      ),
    );

    final result = await cancelAppointment(event.turnId);

    await result.fold(
      (Failure failure) async {
        emit(
          state.copyWith(
            clearCancellingId: true,
            cancelFailure: failure,
            cancelFailureId: event.turnId,
          ),
        );
      },
      (Appointment _) async {
        // The cancelled turn may no longer belong in THIS scope (an upcoming
        // one just became a past one), and patching it in place would have to
        // reimplement that rule here. Asking again is the same call this
        // bloc already makes on every reload, and it is the one place the
        // rule already lives — same reasoning as `BookingBloc._onConfirmed`
        // re-fetching availability after a booking lands.
        emit(state.copyWith(clearCancellingId: true, clearCancelFailure: true));
        await _onRequested(const AppointmentsRequested(), emit);
      },
    );
  }
}
