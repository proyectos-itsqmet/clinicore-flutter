import 'package:dartz/dartz.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/establishment.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this.remote);

  final BookingRemoteDataSource remote;

  @override
  Future<Either<Failure, List<Establishment>>> getEstablishments() {
    return guardFailure(() async {
      final models = await remote.fetchEstablishments();
      return models.map((model) => model.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, List<ServiceWithDoctors>>> getServicesWithDoctors(
    int establishmentId,
  ) {
    return guardFailure(() async {
      final services = await remote.fetchServicesForEstablishment(
        establishmentId,
      );
      if (services.isEmpty) return const <ServiceWithDoctors>[];

      // In PARALLEL, and still in the SERVICES' own order: `Future.wait`
      // collects each future's result at its ORIGINAL index, regardless of
      // which one actually answers first. `clinicore-angular`'s
      // `loadServicesForEstablishment` gets this wrong on purpose-adjacent
      // code — it pushes into a shared array from each `subscribe`, in
      // COMPLETION order, so the board re-renders in a different order on
      // every load. Collecting by index instead of by arrival is what this
      // port does differently.
      final doctorsByService = await Future.wait(
        services.map(
          (service) => remote.fetchDoctorsForService(service.id),
        ),
      );

      return <ServiceWithDoctors>[
        for (int i = 0; i < services.length; i++)
          ServiceWithDoctors(
            service: services[i].toEntity(),
            doctors: doctorsByService[i]
                .map((doctor) => doctor.toEntity())
                .toList(),
          ),
      ];
    });
  }

  @override
  Future<Either<Failure, List<BookingSlot>>> getFreeSchedules({
    required int establishmentId,
    required int serviceId,
    String? doctorId,
    DateTime? date,
  }) {
    return guardFailure(() async {
      final models = await remote.fetchFreeSchedules(
        establishmentId: establishmentId,
        serviceId: serviceId,
        doctorId: doctorId,
        date: date,
      );

      // No `.where(...)` on `doctorId` here. It already reached the
      // request above — filtering the result AGAIN by doctor would
      // silently reintroduce `loadAvailableSchedules`'s bug one layer up:
      // slots past whatever page the data source asked for would still be
      // invisible.
      //
      // `toEntity` returns null for a row with no id, no date or no hour —
      // `whereType` is what drops those.
      return models
          .map((model) => model.toEntity())
          .whereType<BookingSlot>()
          .toList();
    });
  }

  @override
  Future<Either<Failure, Appointment>> book(int scheduleId) {
    return guardFailure(() async {
      final model = await remote.bookTurn(scheduleId);
      return model.toEntity();
    });
  }
}
