import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/data/models/availability_model.dart';
import 'package:clinicore_flutter/features/home/data/models/establishment_model.dart';
import 'package:clinicore_flutter/features/home/data/repositories/booking_repository_impl.dart';
import 'package:clinicore_flutter/features/home/domain/entities/availability.dart';
import 'package:clinicore_flutter/features/home/domain/entities/establishment.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_datasources.dart';

/// Tests for the two places `BookingRepositoryImpl` has to get right that no
/// bloc test can demonstrate — the bloc tests all go through
/// `FakeBookingRepository`, one layer above this one.
///
/// Both regressions being guarded live in `clinicore-angular`'s
/// `booking-page.ts`, and the brief is explicit that this port must NOT
/// repeat them:
///
/// * `loadServicesForEstablishment` pushes into a shared array from each
///   `subscribe`, in COMPLETION order — the board renders a different order
///   on every load.
/// * `loadAvailableSchedules` fetches one page and filters by doctor
///   CLIENT-SIDE, so a doctor's slots past that page are invisible.
void main() {
  late FakeBookingRemoteDataSource remote;
  late BookingRepositoryImpl repository;

  setUp(() {
    remote = FakeBookingRemoteDataSource();
    repository = BookingRepositoryImpl(remote);
  });

  group('getEstablishments', () {
    test('maps the establishments the server returned', () async {
      remote.establishments = const <EstablishmentModel>[
        EstablishmentModel(
          id: 1,
          name: 'Sede Norte',
          address: 'Av. Siempre Viva 742',
        ),
      ];

      final result = await repository.getEstablishments();

      final List<Establishment> establishments = result.fold(
        (Failure f) => throw StateError('expected Right, got $f'),
        (List<Establishment> value) => value,
      );
      expect(establishments.single.name, 'Sede Norte');
      expect(establishments.single.address, 'Av. Siempre Viva 742');
    });

    test('a data-source failure becomes a Failure, not an exception', () async {
      remote.establishmentsError = const NetworkException(message: 'x');

      final result = await repository.getEstablishments();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getServicesWithDoctors', () {
    test('an establishment with no services asks for no doctors', () async {
      remote.servicesByEstablishment[7] = const <BookingServiceModel>[];

      final result = await repository.getServicesWithDoctors(7);

      expect(
        result,
        const Right<Failure, List<ServiceWithDoctors>>(<ServiceWithDoctors>[]),
      );
      expect(remote.doctorsRequestedForServiceIds, isEmpty);
    });

    test('asks for the doctors of EVERY service, not just the first', () async {
      remote.servicesByEstablishment[7] = const <BookingServiceModel>[
        BookingServiceModel(id: 1, name: 'Consulta', price: 30),
        BookingServiceModel(id: 2, name: 'Control', price: 20),
      ];

      await repository.getServicesWithDoctors(7);

      expect(remote.doctorsRequestedForServiceIds, containsAll(<int>[1, 2]));
    });

    test(
      'keeps the SERVICES order even when their doctor requests answer out '
      'of order',
      () async {
        // Service 1 is the SLOW one on purpose: if the repository collected
        // results in completion order (the Angular bug), service 2 would
        // land first here.
        remote.servicesByEstablishment[9] = const <BookingServiceModel>[
          BookingServiceModel(id: 1, name: 'Consulta', price: 30),
          BookingServiceModel(id: 2, name: 'Control', price: 20),
        ];
        remote.doctorsByService[1] = const <BookingDoctorModel>[
          BookingDoctorModel(uuid: 'd-1', firstName: 'Ana', lastName: 'Torres'),
        ];
        remote.doctorsByService[2] = const <BookingDoctorModel>[
          BookingDoctorModel(uuid: 'd-2', firstName: 'Luis', lastName: 'Mora'),
        ];
        remote.doctorDelayByServiceId[1] = const Duration(milliseconds: 30);
        remote.doctorDelayByServiceId[2] = const Duration(milliseconds: 5);

        final result = await repository.getServicesWithDoctors(9);

        final List<ServiceWithDoctors> offers = result.fold(
          (Failure f) => throw StateError('expected Right, got $f'),
          (List<ServiceWithDoctors> value) => value,
        );

        expect(offers.map((ServiceWithDoctors o) => o.service.id), <int>[
          1,
          2,
        ]);
        expect(offers[0].doctors.single.uuid, 'd-1');
        expect(offers[1].doctors.single.uuid, 'd-2');
      },
    );

    test('a failure fetching services becomes a Failure', () async {
      remote.servicesError = const ServerException(message: 'x');

      final result = await repository.getServicesWithDoctors(7);

      expect(result.isLeft(), isTrue);
    });
  });

  group('getFreeSchedules', () {
    test('forwards the chosen doctor and date WITH the request', () async {
      await repository.getFreeSchedules(
        establishmentId: 7,
        serviceId: 1,
        doctorId: 'd-1',
        date: DateTime(2026, 11, 12),
      );

      expect(remote.lastScheduleEstablishmentId, 7);
      expect(remote.lastScheduleServiceId, 1);
      expect(remote.lastScheduleDoctorId, 'd-1');
      expect(remote.lastScheduleDate, DateTime(2026, 11, 12));
    });

    test('sends no doctor filter at all when none was chosen', () async {
      await repository.getFreeSchedules(establishmentId: 7, serviceId: 1);

      expect(remote.lastScheduleDoctorId, isNull);
    });

    test(
      'returns exactly what the server sent — no doctor filtering applied '
      'again on the result',
      () async {
        // The regression this guards: filtering this list AGAIN by doctor
        // here would silently reintroduce `loadAvailableSchedules`'ss bug —
        // slots past whatever page the data source asked for would still be
        // invisible, just one layer higher up.
        remote.schedules = <BookingSlotModel>[
          BookingSlotModel(
            id: 101,
            date: DateTime(2026, 11, 12),
            hour: '09:00',
            status: 'STATUS_FREE',
          ),
          BookingSlotModel(
            id: 102,
            date: DateTime(2026, 11, 12),
            hour: '10:00',
            status: 'STATUS_FREE',
          ),
        ];

        final result = await repository.getFreeSchedules(
          establishmentId: 7,
          serviceId: 1,
          doctorId: 'd-1',
        );

        final List<BookingSlot> slots = result.fold(
          (Failure f) => throw StateError('expected Right, got $f'),
          (List<BookingSlot> value) => value,
        );
        expect(slots.map((BookingSlot s) => s.scheduleId), <int>[101, 102]);
      },
    );

    test('a failure fetching schedules becomes a Failure', () async {
      remote.schedulesError = const NetworkException(message: 'x');

      final result = await repository.getFreeSchedules(
        establishmentId: 7,
        serviceId: 1,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('book', () {
    test('books the exact schedule id it was given', () async {
      await repository.book(103);

      expect(remote.lastBookedScheduleId, 103);
    });
  });
}
