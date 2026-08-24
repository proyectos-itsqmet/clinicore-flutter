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
