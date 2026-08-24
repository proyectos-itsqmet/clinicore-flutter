import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/appointment.dart';
import '../entities/availability.dart';

/// Everything "Agendar" needs, in the order the three steps need it.
abstract interface class BookingRepository {
  /// Step 1's two lists. Fetched TOGETHER because the screen cannot render its
  /// first step without both, and two sequential awaits would show the doctor
  /// chips a beat before the type switch above them.
  Future<Either<Failure, BookingOptions>> getOptions();

  /// Steps 2 and 3, from one request.
  ///
  /// [from] / [to] bound the search. The repository picks the window when the
  /// caller does not — see the impl — because "how far ahead can I book" is a
  /// product rule, not a screen's decision.
  Future<Either<Failure, BookingAvailability>> getAvailability({
    required String doctorId,
    required int serviceId,
    DateTime? from,
    DateTime? to,
  });

  /// Books one slot. Returns the created turn so the screen can show its
  /// ticket number instead of just "reservado".
  Future<Either<Failure, Appointment>> book(int scheduleId);
}

/// What step 1 offers.
class BookingOptions {
  const BookingOptions({required this.doctors, required this.services});

  final List<BookingDoctor> doctors;
  final List<BookingService> services;

  /// Either list being empty means the flow cannot start: no doctors, or no
  /// service to book. The screen says which, because "no hay turnos" when the
  /// clinic has no services configured sends the patient to call reception for
  /// the wrong reason.
  bool get isIncomplete => doctors.isEmpty || services.isEmpty;
}
