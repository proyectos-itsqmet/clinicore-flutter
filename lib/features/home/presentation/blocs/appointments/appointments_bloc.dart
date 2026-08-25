import 'dart:async';

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
///
/// ## Realtime is layered on top, not a separate mode
///
/// This bloc also subscribes to [watchTurnUpdates] for as long as it is
/// alive. That subscription starts in the constructor and ends in [close],
/// which means it connects exactly when the patient is authenticated and
/// looking at an appointments list — the only time this bloc exists at all —
/// and disconnects the moment the bloc closes, whether that is the screen
/// going away or the router tearing down the whole authenticated shell on
/// sign-out. No separate "on logout, disconnect" code needed anywhere for
/// that — see `TurnUpdatesRemoteDataSource`'s class doc for the rest of the
/// chain.
class AppointmentsBloc extends Bloc<AppointmentsEvent, AppointmentsState> {
  AppointmentsBloc({
    required this.getMyAppointments,
    required this.cancelAppointment,
    required this.watchTurnUpdates,
    required this.scope,
  }) : super(const AppointmentsState.initial()) {
    on<AppointmentsRequested>(_onRequested);
    on<AppointmentCancelRequested>(_onCancelRequested);
    on<AppointmentRealtimeUpdateReceived>(_onRealtimeUpdateReceived);

    _realtimeSubscription = watchTurnUpdates().listen(
      (Appointment appointment) =>
          add(AppointmentRealtimeUpdateReceived(appointment)),
    );
  }

  final GetMyAppointments getMyAppointments;
  final CancelAppointment cancelAppointment;
  final WatchTurnUpdates watchTurnUpdates;
  final AppointmentScope scope;

  /// Never emits an error onto this subscription — see `WatchTurnUpdates`'s
  /// doc — so there is no `onError` callback below: a dropped connection is
  /// silence, not a failure this bloc has to react to.
  late final StreamSubscription<Appointment> _realtimeSubscription;

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

  /// Reacts to a server push by reloading THIS scope — see
  /// [AppointmentRealtimeUpdateReceived]'s doc for why a reload and not a
  /// patch.
  ///
  /// Deliberately does not go through the `loading` status: [_onRequested]
  /// sets it so the very first load can show a skeleton, but a background
  /// push arriving on a list already on screen must not collapse it back
  /// into one — that would make "realtime" look like a worse pull-to-refresh.
  Future<void> _onRealtimeUpdateReceived(
    AppointmentRealtimeUpdateReceived event,
    Emitter<AppointmentsState> emit,
  ) async {
    final result = await getMyAppointments(
      GetMyAppointmentsParams(scope: scope),
    );

    emit(
      result.fold(
        // A transient failure here (the same network blip that likely broke
        // the socket in the first place) must not blank out or error a list
        // the patient is already looking at — see `TurnUpdatesRemoteDataSource`
        // and `AppointmentsRepository.watchTurnUpdates` for the same rule
        // applied one layer down. A dead SESSION is the one exception: it is
        // worth surfacing here too, the same way an explicit reload already
        // does, so a patient does not sit on a page that will never update
        // again until they happen to pull to refresh.
        (Failure failure) => failure is SessionExpiredFailure
            ? state.copyWith(status: AppointmentsStatus.failure, failure: failure)
            : state,
        (AppointmentPage page) => state.copyWith(
          status: AppointmentsStatus.ready,
          items: page.items,
          clearFailure: true,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _realtimeSubscription.cancel();
    return super.close();
  }
}
