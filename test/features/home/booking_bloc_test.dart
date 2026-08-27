import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/availability.dart';
import 'package:clinicore_flutter/features/home/domain/entities/establishment.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/booking_usecases.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/booking/booking_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repositories.dart';

/// Tests for the wizard steps `clinicore-angular`'s `booking-page.ts` defines:
/// 1 Sede, 2 Servicio y Doctor, 3 Horario, 4 Confirmado. Every test drives the
/// REAL [BookingBloc] against a [FakeBookingRepository] — the use cases in
/// between are real too, because "did the bloc wire them up" is part of what
/// this checks.
void main() {
  late FakeBookingRepository repository;

  setUp(() => repository = FakeBookingRepository());

  /// 08:00 on [testDay], which is BEFORE both fixture slots (09:00 and 10:00).
  ///
  /// Step 3 refuses to list a slot that has already begun, so the clock is now
  /// part of every step-3 fixture: with a real `DateTime.now()` these tests
  /// would assert on a list whose contents depend on when the suite runs.
  final DateTime testClock = DateTime(2026, 11, 12, 8);

  BookingBloc buildBloc({DateTime? clock}) => BookingBloc(
    getEstablishments: GetEstablishments(repository),
    getServicesWithDoctors: GetServicesWithDoctors(repository),
    getFreeSchedules: GetFreeSchedules(repository),
    bookSlot: BookSlot(repository),
    clock: () => clock ?? testClock,
  );

  /// Walks a fresh bloc to step 3 with `testEstablishments[0]`,
  /// `testConsultationService` and `testDoctors[0]`, and returns it.
  Future<BookingBloc> bookingAtScheduleStep({DateTime? clock}) async {
    final BookingBloc bloc = buildBloc(clock: clock)
      ..add(const BookingStarted());
    await bloc.stream.firstWhere((s) => s.step == BookingStep.establishment && s.establishments.isNotEmpty);

    bloc.add(BookingEstablishmentSelected(testEstablishments[0]));
    await bloc.stream.firstWhere((s) => s.step == BookingStep.serviceAndDoctor && s.status == BookingStatus.ready);

    bloc.add(
      BookingServiceAndDoctorSelected(testConsultationService, testDoctors[0]),
    );
    await bloc.stream.firstWhere((s) => s.step == BookingStep.schedule && s.status == BookingStatus.ready);

    return bloc;
  }

  group('step 1 — Sede', () {
    test('starts on the establishment step, unanswered', () {
      final BookingBloc bloc = buildBloc();
      expect(bloc.state.step, BookingStep.establishment);
      expect(bloc.state.establishment, isNull);
      bloc.close();
    });

    test('BookingStarted loads the list once', () async {
      final BookingBloc bloc = buildBloc()..add(const BookingStarted());
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.status == BookingStatus.ready,
      );

      expect(state.establishments, testEstablishments);
      expect(repository.getEstablishmentsCallCount, 1);
      await bloc.close();
    });

    test('a load failure lands in failure, not in an empty list', () async {
      repository.establishmentsResult = const Left<Failure, List<Establishment>>(
        NetworkFailure(),
      );

      final BookingBloc bloc = buildBloc()..add(const BookingStarted());
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.status == BookingStatus.failure,
      );

      expect(state.failure, isA<NetworkFailure>());
      await bloc.close();
    });

    test('the search box filters the loaded list WITHOUT a new fetch', () async {
      final BookingBloc bloc = buildBloc()..add(const BookingStarted());
      await bloc.stream.firstWhere((s) => s.status == BookingStatus.ready);

      bloc.add(const BookingEstablishmentSearchChanged('sur'));
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.establishmentSearch == 'sur',
      );

      expect(state.visibleEstablishments, <Establishment>[testEstablishments[1]]);
      // Still the ONE call from BookingStarted — typing must not re-fetch.
      expect(repository.getEstablishmentsCallCount, 1);
      await bloc.close();
    });
  });

  group('step 1 -> step 2', () {
    test(
      'picking a sede advances to step 2 and scopes the fetch to it',
      () async {
        final BookingBloc bloc = buildBloc()..add(const BookingStarted());
        await bloc.stream.firstWhere((s) => s.status == BookingStatus.ready);

        bloc.add(BookingEstablishmentSelected(testEstablishments[0]));
        final BookingState state = await bloc.stream.firstWhere(
          (s) => s.step == BookingStep.serviceAndDoctor && s.status == BookingStatus.ready,
        );

        expect(state.establishment, testEstablishments[0]);
        expect(state.servicesWithDoctors, testServiceOffers);
        expect(repository.lastServicesEstablishmentId, testEstablishments[0].id);
        await bloc.close();
      },
    );
  });

  group('step 2 — Servicio y Doctor', () {
    test(
      'picking a service WITH a doctor forwards the doctor to the schedules request',
      () async {
        // This is the regression `clinicore-angular`'s `loadAvailableSchedules`
        // does not guard against: it fetches a page and filters by doctor
        // CLIENT-SIDE, so a doctor's slots past that page are invisible. Here
        // the doctor must reach the CALL, not be applied to its result.
        final BookingBloc bloc = await bookingAtScheduleStep();

        expect(repository.lastSchedulesDoctorId, testDoctors[0].uuid);
        expect(repository.lastSchedulesServiceId, testConsultationService.id);
        expect(
          repository.lastSchedulesEstablishmentId,
          testEstablishments[0].id,
        );
        expect(bloc.state.doctor, testDoctors[0]);
        await bloc.close();
      },
    );

    test('picking "cualquier doctor" sends no doctor filter at all', () async {
      final BookingBloc bloc = buildBloc()..add(const BookingStarted());
      await bloc.stream.firstWhere((s) => s.status == BookingStatus.ready);
      bloc.add(BookingEstablishmentSelected(testEstablishments[0]));
      await bloc.stream.firstWhere((s) => s.step == BookingStep.serviceAndDoctor);

      bloc.add(BookingServiceAndDoctorSelected(testConsultationService, null));
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.step == BookingStep.schedule && s.status == BookingStatus.ready,
      );

      expect(state.doctor, isNull);
      expect(repository.lastSchedulesDoctorId, isNull);
      await bloc.close();
    });
  });

  group('step 3 — Horario', () {
    test('a date filter change reaches the request', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();

      bloc.add(BookingDateFilterChanged(DateTime(2026, 11, 20)));
      final BookingState state = await bloc.stream.firstWhere(
        (s) =>
            s.status == BookingStatus.ready &&
            s.dateFilter == DateTime(2026, 11, 20),
      );

      expect(state.dateFilter, DateTime(2026, 11, 20));
      expect(repository.lastSchedulesDate, DateTime(2026, 11, 20));
      await bloc.close();
    });

    test('there is no "todos los dias": every request names ONE day', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();
      bloc.add(BookingDateFilterChanged(DateTime(2026, 11, 20)));
      await bloc.stream.firstWhere(
        (s) =>
            s.status == BookingStatus.ready &&
            s.dateFilter == DateTime(2026, 11, 20),
      );

      // The bug this replaces: a null date sent NO `date` parameter, so the
      // server answered with every free slot across every day at once.
      expect(repository.schedulesRequestedDates, isNotEmpty);
      expect(repository.schedulesRequestedDates, everyElement(isNotNull));
      await bloc.close();
    });

    test('selecting a schedule records it without booking yet', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();

      bloc.add(BookingScheduleSelected(testSlots[1]));
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.schedule != null,
      );

      expect(state.schedule, testSlots[1]);
      expect(state.step, BookingStep.schedule);
      expect(repository.lastBookedScheduleId, isNull);
      await bloc.close();
    });
  });

  group('step 3 — a slot that already started is not on offer', () {
    test('a slot whose hour has passed never reaches the state', () async {
      // 09:30. testSlots holds 09:00 and 10:00, both STATUS_FREE — nobody
      // booked the 09:00, which is exactly why the server still returns it
      // and why the app has to be the one to drop it.
      final BookingBloc bloc = await bookingAtScheduleStep(
        clock: DateTime(2026, 11, 12, 9, 30),
      );

      expect(bloc.state.schedules, hasLength(1));
      expect(bloc.state.schedules.single.time, '10:00');
      await bloc.close();
    });

    test('a day whose slots have ALL passed reads as empty', () async {
      final BookingBloc bloc = await bookingAtScheduleStep(
        clock: DateTime(2026, 11, 12, 23),
      );

      bloc.add(BookingDateFilterChanged(testDay));
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.status == BookingStatus.ready && s.dateFilter == testDay,
      );

      // The reason the filter lives in the bloc and not in the widget: with a
      // widget-side filter the state would still say "two slots" here, and
      // `hasNoSchedules` — the only thing that tells the patient to try
      // another day — would stay false on the one day it is needed.
      expect(state.schedules, isEmpty);
      expect(state.hasNoSchedules, isTrue);
      await bloc.close();
    });

    test('the day boundary is respected, not just the hour', () async {
      // 08:00 on the 13th. The fixture slots are 09:00 and 10:00 on the 12th:
      // later HOURS, earlier DAY. Comparing hours alone would keep both.
      final BookingBloc bloc = await bookingAtScheduleStep(
        clock: DateTime(2026, 11, 13, 8),
      );

      bloc.add(BookingDateFilterChanged(testDay));
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.status == BookingStatus.ready && s.dateFilter == testDay,
      );

      expect(state.schedules, isEmpty);
      await bloc.close();
    });
  });

  group('step 3 — the day it opens on', () {
    final DateTime today = DateTime(2026, 11, 12);
    final DateTime tomorrow = DateTime(2026, 11, 13);

    test('opens on TODAY when today still has slots', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();

      expect(bloc.state.dateFilter, today);
      expect(repository.schedulesRequestedDates, <DateTime>[today]);
      await bloc.close();
    });

    test('falls through to TOMORROW when today is spent', () async {
      repository.schedulesByDate = <DateTime, List<BookingSlot>>{
        today: <BookingSlot>[],
        tomorrow: <BookingSlot>[
          BookingSlot(
            scheduleId: 900,
            date: tomorrow,
            time: '08:00',
            isFree: true,
          ),
        ],
      };

      // 19:00: the clinic's day is over, but tomorrow's is not.
      final BookingBloc bloc = await bookingAtScheduleStep(
        clock: DateTime(2026, 11, 12, 19),
      );

      expect(repository.schedulesRequestedDates, <DateTime>[today, tomorrow]);
      expect(bloc.state.dateFilter, tomorrow);
      expect(bloc.state.schedules, hasLength(1));
      await bloc.close();
    });

    test('never emits the empty today on the way to tomorrow', () async {
      repository.schedulesByDate = <DateTime, List<BookingSlot>>{
        today: <BookingSlot>[],
        tomorrow: <BookingSlot>[
          BookingSlot(
            scheduleId: 900,
            date: tomorrow,
            time: '08:00',
            isFree: true,
          ),
        ],
      };

      final BookingBloc bloc = buildBloc(clock: DateTime(2026, 11, 12, 19))
        ..add(const BookingStarted());
      await bloc.stream.firstWhere((s) => s.establishments.isNotEmpty);
      bloc.add(BookingEstablishmentSelected(testEstablishments[0]));
      await bloc.stream.firstWhere(
        (s) => s.step == BookingStep.serviceAndDoctor && s.status == BookingStatus.ready,
      );

      final List<BookingState> seen = <BookingState>[];
      final sub = bloc.stream.listen(seen.add);

      bloc.add(
        BookingServiceAndDoctorSelected(testConsultationService, testDoctors[0]),
      );
      await bloc.stream.firstWhere(
        (s) => s.status == BookingStatus.ready && s.dateFilter == tomorrow,
      );
      await sub.cancel();

      // A `ready` empty today between the two requests would flash "Sin
      // horarios libres" for one frame on a screen about to show a full list.
      expect(
        seen.where(
          (BookingState s) =>
              s.status == BookingStatus.ready &&
              s.dateFilter == today &&
              s.schedules.isEmpty,
        ),
        isEmpty,
      );
      await bloc.close();
    });

    test('a FAILED today is reported, never retried as tomorrow', () async {
      repository.schedulesResult = const Left<Failure, List<BookingSlot>>(
        ServerFailure(message: 'Se cayo el servidor'),
      );

      final BookingBloc bloc = buildBloc()..add(const BookingStarted());
      await bloc.stream.firstWhere((s) => s.establishments.isNotEmpty);
      bloc.add(BookingEstablishmentSelected(testEstablishments[0]));
      await bloc.stream.firstWhere(
        (s) => s.step == BookingStep.serviceAndDoctor && s.status == BookingStatus.ready,
      );
      bloc.add(
        BookingServiceAndDoctorSelected(testConsultationService, testDoctors[0]),
      );
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.status == BookingStatus.failure,
      );

      // Silently moving to tomorrow would answer a question nobody asked and
      // bury the real error. One request, one honest failure.
      expect(repository.schedulesRequestedDates, <DateTime>[today]);
      expect(state.failure, isA<ServerFailure>());
      // The chip still has to show which day failed, or "Reintentar" has
      // nothing to retry against.
      expect(state.dateFilter, today);
      await bloc.close();
    });
  });

  group('step 3 -> step 4', () {
    test('confirming books the SCHEDULE id, not the chip index', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();
      bloc.add(BookingScheduleSelected(testSlots[1]));
      await bloc.stream.firstWhere((s) => s.schedule != null);

      bloc.add(const BookingConfirmed());
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.step == BookingStep.confirmed,
      );

      // testSlots[1] is scheduleId 103 in the fixture. Booking its INDEX (1)
      // or the first row's id (102) would both send the patient to the wrong
      // slot.
      expect(repository.lastBookedScheduleId, 103);
      expect(state.booked, isNotNull);
      expect(state.status, BookingStatus.booked);
      await bloc.close();
    });

    test(
      'a booking failure surfaces WITHOUT losing the selections or the step',
      () async {
        repository.bookResult = const Left<Failure, Appointment>(
          ValidationFailure(message: 'Ese cupo ya fue tomado.'),
        );

        final BookingBloc bloc = await bookingAtScheduleStep();
        bloc.add(BookingScheduleSelected(testSlots[1]));
        await bloc.stream.firstWhere((s) => s.schedule != null);

        bloc.add(const BookingConfirmed());
        final BookingState state = await bloc.stream.firstWhere(
          (s) => s.status == BookingStatus.failure,
        );

        expect(state.failure, isA<ValidationFailure>());
        // Still on step 3, and every choice the patient made is intact — a
        // failed booking must not send them back to pick everything again.
        expect(state.step, BookingStep.schedule);
        expect(state.establishment, testEstablishments[0]);
        expect(state.service, testConsultationService);
        expect(state.doctor, testDoctors[0]);
        expect(state.schedule, testSlots[1]);
        await bloc.close();
      },
    );
  });

  group('back navigation', () {
    test('moves to an earlier step', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();

      bloc.add(const BookingStepBackRequested(BookingStep.establishment));
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.step == BookingStep.establishment,
      );

      expect(state.step, BookingStep.establishment);
      // Going BACK does not discard the choices — only re-selecting does.
      expect(state.establishment, testEstablishments[0]);
      expect(state.service, testConsultationService);
      await bloc.close();
    });

    test('a request to skip FORWARD is ignored', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();
      final BookingStep before = bloc.state.step;

      bloc.add(const BookingStepBackRequested(BookingStep.confirmed));
      // No transition to wait for — this asserts that NOTHING changes, so a
      // settling delay stands in for "no event was emitted".
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.step, before);
      await bloc.close();
    });

    test(
      'picking a DIFFERENT sede after going back clears service, doctor and schedule',
      () async {
        final BookingBloc bloc = await bookingAtScheduleStep();
        bloc.add(BookingScheduleSelected(testSlots[0]));
        await bloc.stream.firstWhere((s) => s.schedule != null);

        bloc.add(const BookingStepBackRequested(BookingStep.establishment));
        await bloc.stream.firstWhere(
          (s) => s.step == BookingStep.establishment,
        );

        bloc.add(BookingEstablishmentSelected(testEstablishments[1]));
        final BookingState state = await bloc.stream.firstWhere(
          (s) => s.step == BookingStep.serviceAndDoctor && s.status == BookingStatus.ready,
        );

        expect(state.establishment, testEstablishments[1]);
        expect(state.service, isNull);
        expect(state.doctor, isNull);
        expect(state.schedule, isNull);
        expect(repository.lastServicesEstablishmentId, testEstablishments[1].id);
        await bloc.close();
      },
    );
  });

  group('BookingReset', () {
    test('forgets every selection but keeps the loaded sedes', () async {
      final BookingBloc bloc = await bookingAtScheduleStep();
      bloc.add(BookingScheduleSelected(testSlots[0]));
      await bloc.stream.firstWhere((s) => s.schedule != null);
      bloc.add(const BookingConfirmed());
      await bloc.stream.firstWhere((s) => s.step == BookingStep.confirmed);

      bloc.add(const BookingReset());
      final BookingState state = await bloc.stream.firstWhere(
        (s) => s.step == BookingStep.establishment,
      );

      expect(state.establishment, isNull);
      expect(state.service, isNull);
      expect(state.doctor, isNull);
      expect(state.schedule, isNull);
      expect(state.booked, isNull);
      // No second fetch — the list step 1 already has is still good.
      expect(state.establishments, testEstablishments);
      expect(repository.getEstablishmentsCallCount, 1);
      await bloc.close();
    });
  });
}
