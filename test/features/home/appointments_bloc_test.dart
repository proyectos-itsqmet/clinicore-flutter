import 'dart:async';

import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/appointments_repository.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/appointments_usecases.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/appointments/appointments_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repositories.dart';

/// Tests for the realtime half of [AppointmentsBloc] — the REST half (load,
/// cancel) is already covered end-to-end through the screen in
/// `screens_test.dart`. These drive the REAL bloc and the REAL
/// [WatchTurnUpdates] usecase against a [FakeAppointmentsRepository], the
/// same shape `booking_bloc_test.dart` uses for [BookingBloc]: no mocking
/// package, a hand-written fake, and a `StreamController` standing in for
/// the socket — see `FakeAppointmentsRepository.turnUpdatesController`.
void main() {
  late FakeAppointmentsRepository repository;

  setUp(() => repository = FakeAppointmentsRepository());

  AppointmentsBloc buildBloc({
    AppointmentScope scope = AppointmentScope.upcoming,
  }) {
    return AppointmentsBloc(
      getMyAppointments: GetMyAppointments(repository),
      cancelAppointment: CancelAppointment(repository),
      watchTurnUpdates: WatchTurnUpdates(repository),
      scope: scope,
    );
  }

  void seedUpcoming(List<Appointment> items) {
    repository.results[AppointmentScope.upcoming] = Right<Failure, AppointmentPage>(
      AppointmentPage(
        items: items,
        page: 0,
        isLast: true,
        totalElements: items.length,
      ),
    );
  }

  group('subscription lifecycle', () {
    test('starts listening for pushes as soon as it is built', () {
      final AppointmentsBloc bloc = buildBloc();

      expect(repository.turnUpdatesController.hasListener, isTrue);

      bloc.close();
    });

    test('stops listening once closed', () async {
      final AppointmentsBloc bloc = buildBloc();
      expect(repository.turnUpdatesController.hasListener, isTrue);

      await bloc.close();

      // This is the mechanism that makes "disconnect on logout" true without
      // any bloc knowing what a logout is: closing the bloc — which the
      // router already does for every home bloc when it tears down the
      // authenticated shell — cancels this subscription, and the datasource
      // closes the socket the moment its last listener goes. See
      // `TurnUpdatesRemoteDataSource`.
      expect(repository.turnUpdatesController.hasListener, isFalse);
    });
  });

  group('an inbound push', () {
    test('reloads this scope and the new list reaches the state', () async {
      seedUpcoming(testUpcoming);
      final AppointmentsBloc bloc = buildBloc()
        ..add(const AppointmentsRequested());
      await bloc.stream.firstWhere((s) => s.status == AppointmentsStatus.ready);
      expect(bloc.state.items, testUpcoming);

      // The server's list changed; nothing in this bloc asked for it again —
      // the push itself is what must trigger the reload.
      seedUpcoming(const <Appointment>[]);
      repository.turnUpdatesController.add(testUpcoming[0]);

      final AppointmentsState state = await bloc.stream.firstWhere(
        (s) => s.items.isEmpty,
      );

      expect(state.status, AppointmentsStatus.ready);
      expect(
        repository.requestedScopes
            .where((scope) => scope == AppointmentScope.upcoming)
            .length,
        greaterThanOrEqualTo(2),
      );
      await bloc.close();
    });

    test('never puts the list back into a loading skeleton', () async {
      seedUpcoming(testUpcoming);
      final AppointmentsBloc bloc = buildBloc()
        ..add(const AppointmentsRequested());
      await bloc.stream.firstWhere((s) => s.status == AppointmentsStatus.ready);

      final List<AppointmentsStatus> statusesSincePush = <AppointmentsStatus>[];
      final StreamSubscription<AppointmentsState> subscription = bloc.stream
          .listen((AppointmentsState state) => statusesSincePush.add(state.status));

      // The reload must return something DIFFERENT from what is already in
      // state — Bloc.emit skips a state that is `==` the current one, so an
      // unchanged fixture here would mean no new event to observe at all.
      seedUpcoming(const <Appointment>[]);
      repository.turnUpdatesController.add(testUpcoming[0]);
      await bloc.stream.firstWhere((s) => s.items.isEmpty);

      // A push landing on a list already on screen must read as "the list
      // just updated", never as "the list is loading again" — that would
      // make realtime look like a worse pull-to-refresh.
      expect(statusesSincePush, isNot(contains(AppointmentsStatus.loading)));

      await subscription.cancel();
      await bloc.close();
    });

    test(
      'a transient failure on the reload keeps the list already on screen',
      () async {
        seedUpcoming(testUpcoming);
        final AppointmentsBloc bloc = buildBloc()
          ..add(const AppointmentsRequested());
        await bloc.stream.firstWhere(
          (s) => s.status == AppointmentsStatus.ready,
        );

        // The connection drops mid-session: the fetch a push triggers fails
        // like any other request would — this is the resilience contract,
        // not a bug in the fake.
        repository.results[AppointmentScope.upcoming] =
            const Left<Failure, AppointmentPage>(NetworkFailure());
        repository.turnUpdatesController.add(testUpcoming[0]);

        // Nothing distinguishable to await for — the point IS that the state
        // does not change. `Duration.zero` drains every pending microtask
        // this chain can produce, the same idiom `booking_bloc_test.dart`
        // uses to assert "no transition happened".
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, AppointmentsStatus.ready);
        expect(bloc.state.items, testUpcoming);
        await bloc.close();
      },
    );

    test('a dead session still surfaces, the same way an explicit reload does', () async {
      seedUpcoming(testUpcoming);
      final AppointmentsBloc bloc = buildBloc()
        ..add(const AppointmentsRequested());
      await bloc.stream.firstWhere((s) => s.status == AppointmentsStatus.ready);

      repository.results[AppointmentScope.upcoming] =
          const Left<Failure, AppointmentPage>(SessionExpiredFailure());
      repository.turnUpdatesController.add(testUpcoming[0]);

      final AppointmentsState state = await bloc.stream.firstWhere(
        (s) => s.status == AppointmentsStatus.failure,
      );

      expect(state.isSessionExpired, isTrue);
      await bloc.close();
    });
  });
}
