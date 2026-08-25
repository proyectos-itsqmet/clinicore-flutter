import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/appointment.dart';
import '../entities/availability.dart';
import '../entities/establishment.dart';

/// Everything the "Agendar" wizard needs, in the order its four steps need
/// it.
abstract interface class BookingRepository {
  /// Step 1: every establishment a patient can pick from.
  Future<Either<Failure, List<Establishment>>> getEstablishments();

  /// Step 2: the services offered at [establishmentId], each paired with the
  /// doctors who perform it — in the SAME order the server listed the
  /// services, regardless of which doctor request answers first.
  Future<Either<Failure, List<ServiceWithDoctors>>> getServicesWithDoctors(
    int establishmentId,
  );

  /// Step 3: the FREE slots for one service at one establishment.
  ///
  /// [doctorId] and [date] narrow the search when given. Neither is ever
  /// applied to the result AFTER fetching it — both reach the request, so a
  /// doctor's slots are never silently cut by a page size.
  Future<Either<Failure, List<BookingSlot>>> getFreeSchedules({
    required int establishmentId,
    required int serviceId,
    String? doctorId,
    DateTime? date,
  });

  /// Step 4: books one slot. Returns the created turn so the screen can show
  /// its ticket number instead of just "reservado".
  Future<Either<Failure, Appointment>> book(int scheduleId);
}
