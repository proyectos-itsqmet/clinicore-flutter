import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/appointment.dart';
import '../entities/availability.dart';
import '../repositories/booking_repository.dart';

/// Loads step 1: the consultation types and the doctors.
class GetBookingOptions implements UseCase<BookingOptions, NoParams> {
  const GetBookingOptions(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, BookingOptions>> call(NoParams params) {
    return _repository.getOptions();
  }
}

class GetAvailabilityParams extends Equatable {
  const GetAvailabilityParams({
    required this.doctorId,
    required this.serviceId,
  });

  final String doctorId;
  final int serviceId;

  @override
  List<Object?> get props => <Object?>[doctorId, serviceId];
}

/// Loads steps 2 and 3 for one doctor + service pair.
///
/// No date range in the params: the window is a product rule and lives in the
/// repository. A screen that could pass its own would be a screen that can
/// disagree with the next screen about how far ahead booking is allowed.
class GetAvailability
    implements UseCase<BookingAvailability, GetAvailabilityParams> {
  const GetAvailability(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, BookingAvailability>> call(
    GetAvailabilityParams params,
  ) {
    return _repository.getAvailability(
      doctorId: params.doctorId,
      serviceId: params.serviceId,
    );
  }
}

/// Books a slot.
///
/// Takes the SCHEDULE id and nothing else. The patient comes from the token, so
/// there is no parameter through which one patient could book for another.
class BookSlot implements UseCase<Appointment, int> {
  const BookSlot(this._repository);

  final BookingRepository _repository;

  @override
  Future<Either<Failure, Appointment>> call(int scheduleId) {
    return _repository.book(scheduleId);
  }
}
