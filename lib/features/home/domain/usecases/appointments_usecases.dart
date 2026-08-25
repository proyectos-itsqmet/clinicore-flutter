import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/appointment.dart';
import '../repositories/appointments_repository.dart';

/// Which slice, and how much of it.
class GetMyAppointmentsParams extends Equatable {
  const GetMyAppointmentsParams({
    required this.scope,
    this.page = 0,
    this.size = 20,
  });

  final AppointmentScope scope;
  final int page;

  /// 20 and not the server's default 10: the appointments tab shows the whole
  /// list at once, and a patient with a dozen visits scrolling into a second
  /// page they cannot see is worse than one slightly larger request.
  final int size;

  @override
  List<Object?> get props => <Object?>[scope, page, size];
}

/// Reads the signed-in patient's appointments.
///
/// Always through `/api/turns/me`, never `/api/turns` — the repository has no
/// way to express the second one, which is the point. That endpoint returns
/// every turn in the system with other patients' cedulas attached.
class GetMyAppointments
    implements UseCase<AppointmentPage, GetMyAppointmentsParams> {
  const GetMyAppointments(this._repository);

  final AppointmentsRepository _repository;

  @override
  Future<Either<Failure, AppointmentPage>> call(
    GetMyAppointmentsParams params,
  ) {
    return _repository.getMyAppointments(
      scope: params.scope,
      page: params.page,
      size: params.size,
    );
  }
}

/// Cancels one appointment.
///
/// Takes the TURN id and nothing else — there is no parameter through which
/// a caller could cancel somebody else's turn, because the server checks
/// ownership from the token regardless of what is sent here.
class CancelAppointment implements UseCase<Appointment, int> {
  const CancelAppointment(this._repository);

  final AppointmentsRepository _repository;

  @override
  Future<Either<Failure, Appointment>> call(int turnId) {
    return _repository.cancelAppointment(turnId);
  }
}

/// A live feed of the signed-in patient's own turn changes. See
/// `AppointmentsRepository.watchTurnUpdates` for what it does and does not
/// guarantee.
///
/// Not a [UseCase]: that interface is `Future<Either<Failure, T>>`, shaped
/// for a one-shot call a bloc can `await` and `fold`. A live stream is
/// neither — there is no single result, and, deliberately, no failure to
/// fold: a dropped socket should not resolve into an error state, it should
/// just stop pushing until it reconnects.
class WatchTurnUpdates {
  const WatchTurnUpdates(this._repository);

  final AppointmentsRepository _repository;

  Stream<Appointment> call() => _repository.watchTurnUpdates();
}
