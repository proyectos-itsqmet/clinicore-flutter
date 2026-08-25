import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/appointment.dart';
import '../entities/availability.dart';
import '../entities/establishment.dart';
import '../repositories/booking_repository.dart';

/// Loads step 1: the establishments a patient can pick from.
class GetEstablishments implements UseCase<List<Establishment>, NoParams> {
  const GetEstablishments(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, List<Establishment>>> call(NoParams params) {
    return _repository.getEstablishments();
  }
}

/// Loads step 2: the services offered at ONE establishment, each paired
/// with its doctors. Takes the establishment id directly — there is nothing
/// else this step needs to ask with.
class GetServicesWithDoctors
    implements UseCase<List<ServiceWithDoctors>, int> {
  const GetServicesWithDoctors(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, List<ServiceWithDoctors>>> call(
    int establishmentId,
  ) {
    return _repository.getServicesWithDoctors(establishmentId);
  }
}

class GetFreeSchedulesParams extends Equatable {
  const GetFreeSchedulesParams({
    required this.establishmentId,
    required this.serviceId,
    this.doctorId,
    this.date,
  });

  final int establishmentId;
  final int serviceId;

  /// Optional — step 2 lets a patient skip picking a specific doctor.
  final String? doctorId;

  /// Optional. `null` means "every upcoming day" — the web flow's cleared
  /// date filter.
  final DateTime? date;

  @override
  List<Object?> get props => <Object?>[
    establishmentId,
    serviceId,
    doctorId,
    date,
  ];
}

/// Loads step 3: the FREE slots for one service at one establishment,
/// optionally narrowed to one doctor and/or one day.
class GetFreeSchedules
    implements UseCase<List<BookingSlot>, GetFreeSchedulesParams> {
  const GetFreeSchedules(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, List<BookingSlot>>> call(
    GetFreeSchedulesParams params,
  ) {
    return _repository.getFreeSchedules(
      establishmentId: params.establishmentId,
      serviceId: params.serviceId,
      doctorId: params.doctorId,
      date: params.date,
    );
  }
}

/// Books a slot.
///
/// Takes the SCHEDULE id and nothing else. The patient comes from the token,
/// so there is no parameter through which one patient could book for
/// another.
class BookSlot implements UseCase<Appointment, int> {
  const BookSlot(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, Appointment>> call(int scheduleId) {
    return _repository.book(scheduleId);
  }
}
