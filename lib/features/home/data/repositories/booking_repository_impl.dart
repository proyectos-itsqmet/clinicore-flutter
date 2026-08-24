import 'package:dartz/dartz.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/availability.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';
import '../models/availability_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this.remote);

  final BookingRemoteDataSource remote;

  /// How far ahead booking is offered.
  ///
  /// A product rule, which is why it is HERE and not a parameter: a screen that
  /// could choose its own window is a screen that can disagree with the next
  /// one. Sixty days is wide enough for a specialist with a long waitlist and
  /// narrow enough that one request covers it.
  static const Duration _window = Duration(days: 60);

  @override
  Future<Either<Failure, BookingOptions>> getOptions() {
    return guardFailure(() async {
      // In PARALLEL, not one after the other. Step 1 cannot render without
      // both lists, so awaiting them in sequence would just make the screen
      // wait twice for something it needs once.
      final List<Object> results = await Future.wait(<Future<Object>>[
        remote.fetchDoctors(),
        remote.fetchServices(),
      ]);

      final List<BookingDoctorModel> doctors =
          results[0] as List<BookingDoctorModel>;
      final List<BookingServiceModel> services =
          results[1] as List<BookingServiceModel>;

      return BookingOptions(
        doctors: doctors
            .map((BookingDoctorModel model) => model.toEntity())
            .toList(),
        services: services
            .map((BookingServiceModel model) => model.toEntity())
            .toList(),
      );
    });
  }

  @override
  Future<Either<Failure, BookingAvailability>> getAvailability({
    required String doctorId,
    required int serviceId,
    DateTime? from,
    DateTime? to,
  }) {
    return guardFailure(() async {
      final DateTime start = from ?? _today();
      final DateTime end = to ?? start.add(_window);

      final List<BookingSlotModel> models = await remote.fetchSlots(
        doctorId: doctorId,
        serviceId: serviceId,
        from: start,
        to: end,
      );

      // `toEntity` returns null for a row that cannot become a chip — no id,
      // no date or no hour. `whereType` is what drops them, and it is why
      // `BookingSlot` gets to declare all three non-nullable.
      final List<BookingSlot> slots = models
          .map((BookingSlotModel model) => model.toEntity())
          .whereType<BookingSlot>()
          .toList();

      return BookingAvailability(slots: slots);
    });
  }

  @override
  Future<Either<Failure, Appointment>> book(int scheduleId) {
    return guardFailure(() async {
      final model = await remote.bookTurn(scheduleId);
      return model.toEntity();
    });
  }

  /// Midnight local, so a slot later TODAY is still offered.
  ///
  /// Passing `DateTime.now()` would send a time component the server's
  /// `ISO.DATE` parser rejects, and truncating to the day is also the correct
  /// question: the range is inclusive of today.
  DateTime _today() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
