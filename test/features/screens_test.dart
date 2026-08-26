import 'package:clinicore_flutter/core/theme/theme.dart';
import 'package:clinicore_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/appointments_repository.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/appointments_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/booking_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/profile_screen.dart';
import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/auth/auth_bloc.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/availability.dart';
import 'package:clinicore_flutter/features/home/domain/entities/clinical_record.dart';
import 'package:clinicore_flutter/features/home/domain/entities/coverage.dart';
import 'package:clinicore_flutter/features/home/domain/entities/establishment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/patient_profile.dart';
import 'package:clinicore_flutter/features/home/domain/entities/history_entry.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/change_password_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/history_detail_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/history_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/personal_info_screen.dart';
import 'package:clinicore_flutter/shared/helpers/date_labels.dart';
import 'package:clinicore_flutter/shared/ui/atoms/atoms.dart';
import 'package:clinicore_flutter/shared/ui/organisms/organisms.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_home_repositories.dart';
import '../helpers/pump_app.dart';

/// Screen-level tests.
///
/// These are the ones that prove the design system actually composes: an atom
/// can pass its own test and still blow up the moment it is put inside a
/// column inside a card inside a scroll view. Every test below renders a real
/// screen and then asserts `takeException()` is null, which is what catches
/// the overflow errors a unit test never sees.
///
/// As in the design-system tests: NO `pumpAndSettle` here. These screens
/// contain [AppBeam] and [AppLiveDot], whose animations repeat forever.
Widget _host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Taps a label, scrolling to it first.
///
/// The booking screen is taller than the 800x600 test surface — deliberately,
/// it is a three-step form on a phone — so its later steps start off-screen
/// and `tester.tap` cannot reach them. Scrolling first is not a workaround:
/// it is what the user does.
Future<void> _tapLabel(
  WidgetTester tester,
  String label, {
  Duration settle = AppMotion.morph,
  bool warnIfMissed = true,
}) async {
  final Finder finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: warnIfMissed);
  await tester.pump(settle);
}

void main() {
  group('BookingScreen', () {
    late HomeFakes fakes;

    // The screen resolves its BookingBloc from the locator, so the locator has
    // to exist. Only the repository is faked — the use cases and the bloc are
    // real, because "did the screen wire them up" is what these tests check.
    setUp(() => fakes = setUpHomeDependencies());

    /// testSlots[1] (10:00) has no date filter applied by default, so its
    /// chip carries its own date — see `_ScheduleStep`'s label rule.
    String slot10amLabel() => '${shortDate(testDay)} 10:00';

    /// Walks the wizard from a fresh screen to step 3, having picked
    /// `Sede Norte` -> `testConsultationService` + `Ana Torres`.
    Future<void> goToScheduleStep(WidgetTester tester) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();
      await _tapLabel(tester, 'Sede Norte');
      await tester.pump();
      await _tapLabel(tester, 'Ana Torres');
      await tester.pump();
    }

    testWidgets('opens on step 1 and lists the sedes the server returned', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      expect(find.text('PASO 1 DE 4'), findsOneWidget);
      expect(find.text('Sede Norte'), findsOneWidget);
      expect(find.text('Sede Sur'), findsOneWidget);
      // Nothing behind step 1 to go back to.
      expect(find.text('Volver'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking a sede advances to step 2, scoped to THAT sede', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Sede Norte');
      await tester.pump();

      expect(find.text('PASO 2 DE 4'), findsOneWidget);
      expect(fakes.booking.lastServicesEstablishmentId, testEstablishments[0].id);
      expect(find.text('Consulta'), findsOneWidget);
      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('Luis Mora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Volver on step 2 returns to step 1 without a new fetch', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();
      await _tapLabel(tester, 'Sede Norte');
      await tester.pump();

      await _tapLabel(tester, 'Volver');
      await tester.pump();

      expect(find.text('PASO 1 DE 4'), findsOneWidget);
      expect(find.text('Sede Norte'), findsOneWidget);
      expect(fakes.booking.getEstablishmentsCallCount, 1);
    });

    /// The device's own back button, which used to leave the app from the
    /// middle of the wizard — see `_BookingBackGuard`.
    ///
    /// `handlePopRoute` is what the platform sends on a back gesture, so
    /// these go through the same path a real press does rather than calling
    /// the callback directly.
    group('the device back button', () {
      testWidgets('on step 2 goes back one step instead of leaving', (
        tester,
      ) async {
        await pumpApp(tester, const BookingScreen());
        await tester.pump();
        await _tapLabel(tester, 'Sede Norte');
        await tester.pump();
        expect(find.text('PASO 2 DE 4'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump(AppMotion.morph);

        expect(find.text('PASO 1 DE 4'), findsOneWidget);
        expect(find.text('Sede Norte'), findsOneWidget);
      });

      testWidgets('on step 3 keeps the sede and the service already chosen', (
        tester,
      ) async {
        await goToScheduleStep(tester);
        expect(find.text('PASO 3 DE 4'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump(AppMotion.morph);

        // Back is ONE step, not out: the doctor list for the sede picked in
        // step 1 is still on screen. Losing all of it to the most-used
        // gesture on the phone is the bug this replaced.
        expect(find.text('PASO 2 DE 4'), findsOneWidget);
        expect(find.text('Ana Torres'), findsOneWidget);
      });

      testWidgets('on step 1 bubbles, because there is nothing to protect', (
        tester,
      ) async {
        await pumpApp(tester, const BookingScreen());
        await tester.pump();

        await tester.binding.handlePopRoute();
        await tester.pump();

        // Still step 1 and no exception: the guard let the gesture through
        // to the platform rather than swallowing it into a dead end.
        expect(find.text('PASO 1 DE 4'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('on the ticket starts a fresh booking, keeping the sedes', (
        tester,
      ) async {
        await goToScheduleStep(tester);
        await _tapLabel(tester, slot10amLabel());
        await tester.pump();
        await _tapLabel(tester, 'Confirmar turno', settle: AppMotion.press);
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('PASO 4 DE 4'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump(AppMotion.morph);

        // Exactly what "Agendar otro turno" does. Dropping the patient out of
        // the app one gesture after booking reads as a crash, at the moment
        // they are least sure it worked.
        expect(find.text('PASO 1 DE 4'), findsOneWidget);
        expect(find.text('Sede Norte'), findsOneWidget);
        expect(fakes.booking.getEstablishmentsCallCount, 1);
      });
    });

    testWidgets(
      'picking a doctor advances to step 3 and forwards the doctor to the '
      'request — never applied to the result afterwards',
      (tester) async {
        await goToScheduleStep(tester);

        expect(find.text('PASO 3 DE 4'), findsOneWidget);
        expect(fakes.booking.lastSchedulesDoctorId, testDoctors[0].uuid);
        expect(fakes.booking.lastSchedulesServiceId, testConsultationService.id);
        expect(
          fakes.booking.lastSchedulesEstablishmentId,
          testEstablishments[0].id,
        );
        expect(find.text(slot10amLabel()), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '"cualquier doctor" sends no doctor filter at all',
      (tester) async {
        await pumpApp(tester, const BookingScreen());
        await tester.pump();
        await _tapLabel(tester, 'Sede Norte');
        await tester.pump();

        await _tapLabel(
          tester,
          'Cualquier doctor para ${testConsultationService.name}',
        );
        await tester.pump();

        expect(find.text('PASO 3 DE 4'), findsOneWidget);
        expect(fakes.booking.lastSchedulesDoctorId, isNull);
      },
    );

    testWidgets(
      'confirming books the SCHEDULE id and shows the confirmed step',
      (tester) async {
        await goToScheduleStep(tester);

        await _tapLabel(tester, slot10amLabel());
        await tester.pump();
        await _tapLabel(tester, 'Confirmar turno', settle: AppMotion.press);
        // Drains `AppTick`'s draw timer. A bare `pump()` leaves it pending
        // and the test fails on a timer rather than on the assertion — the
        // confirmed step mounts an `AppTick` the moment the booking lands.
        await tester.pump(AppMotion.tickDrawDelay + AppMotion.tickDraw);

        // testSlots[1] (10:00) is scheduleId 103 in the fixture. Booking its
        // chip INDEX (1) or the first row's id (102) would both send the
        // patient to the wrong slot.
        expect(fakes.booking.lastBookedScheduleId, 103);
        expect(find.text('PASO 4 DE 4'), findsOneWidget);
        expect(find.text('Numero de turno: 7'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a booking failure keeps every selection and stays on step 3',
      (tester) async {
        fakes.booking.bookResult = const Left<Failure, Appointment>(
          ValidationFailure(message: 'Ese cupo ya fue tomado.'),
        );

        await goToScheduleStep(tester);
        await _tapLabel(tester, slot10amLabel());
        await tester.pump();
        await _tapLabel(tester, 'Confirmar turno', settle: AppMotion.press);
        await tester.pump();

        // This is the whole reason the confirmation waits for the server —
        // and the patient must not be sent back to pick everything again.
        expect(find.text('Ese cupo ya fue tomado.'), findsOneWidget);
        expect(find.text('PASO 3 DE 4'), findsOneWidget);
        expect(find.text('Sede Norte'), findsOneWidget);
        expect(find.text('Consulta'), findsOneWidget);
        expect(find.text('Ana Torres'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a sede with no services says so, and which sede it was', (
      tester,
    ) async {
      // Not a failure — an empty result the server actually returned, so
      // there is no `Reintentar` here: retrying would ask for the exact
      // same empty list.
      fakes.booking.servicesResult =
          const Right<Failure, List<ServiceWithDoctors>>(<ServiceWithDoctors>[]);

      await pumpApp(tester, const BookingScreen());
      await tester.pump();
      await _tapLabel(tester, 'Sede Norte');
      await tester.pump();

      expect(
        find.textContaining('todavia no tiene servicios'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no free schedules says so instead of an empty list', (
      tester,
    ) async {
      fakes.booking.schedulesResult =
          const Right<Failure, List<BookingSlot>>(<BookingSlot>[]);

      await goToScheduleStep(tester);

      expect(find.textContaining('Sin horarios libres'), findsOneWidget);
    });
  });

  group('AppointmentsScreen', () {
    late HomeFakes fakes;
    setUp(() => fakes = setUpHomeDependencies());

    testWidgets('lists the upcoming appointments the server returned', (
      tester,
    ) async {
      fakes.appointments.results[AppointmentScope.upcoming] =
          Right<Failure, AppointmentPage>(
            AppointmentPage(
              items: testUpcoming,
              page: 0,
              isLast: true,
              totalElements: 2,
            ),
          );

      await pumpApp(tester, const AppointmentsScreen());
      await tester.pump();

      expect(find.text('Pediatria'), findsOneWidget);
      expect(find.text('Sede Norte'), findsOneWidget);
      // The second fixture row has no schedule at all — a row the server
      // really returns. It must still render, with dashes rather than
      // vanishing: it has a ticket number the patient may be asked for.
      expect(find.textContaining('Horario por confirmar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an EMPTY result offers the way out', (tester) async {
      await pumpApp(tester, const AppointmentsScreen());
      await tester.pump();

      expect(find.text('No tienes citas agendadas'), findsOneWidget);
      expect(find.text('Agendar una cita'), findsOneWidget);
    });

    testWidgets('a FAILED load never says the patient has no appointments', (
      tester,
    ) async {
      // The single most damaging thing this screen could say. An empty state
      // after a failed request tells a patient nothing is booked, and they
      // miss the appointment.
      fakes.appointments.results[AppointmentScope.upcoming] =
          const Left<Failure, AppointmentPage>(NetworkFailure());

      await pumpApp(tester, const AppointmentsScreen());
      await tester.pump();

      expect(find.text('No tienes citas agendadas'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    group('pull to refresh', () {
      /// Pulls the list down far enough to arm [RefreshIndicator] and lets it
      /// run. `drag` and not `fling`: a fling leaves a ballistic simulation
      /// running that `pump` has to chase, and this only needs the threshold
      /// crossed.
      Future<void> pullDown(WidgetTester tester) async {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 320),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('reloads the OPEN tab', (tester) async {
        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();
        expect(fakes.appointments.requestedScopes, <AppointmentScope>[
          AppointmentScope.upcoming,
        ]);

        await pullDown(tester);

        expect(fakes.appointments.requestedScopes, <AppointmentScope>[
          AppointmentScope.upcoming,
          AppointmentScope.upcoming,
        ]);
      });

      testWidgets('never touches the tab that is not open', (tester) async {
        // Each scope costs one HTTP request per status server-side, so
        // refreshing the list nobody is looking at spends real requests on
        // nothing — and "Pasadas" may not even have a bloc yet.
        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();

        await pullDown(tester);

        expect(
          fakes.appointments.requestedScopes.contains(AppointmentScope.past),
          isFalse,
        );
      });

      testWidgets('a failed refresh keeps the list that was already there', (
        tester,
      ) async {
        fakes.appointments.results[AppointmentScope.upcoming] =
            Right<Failure, AppointmentPage>(
              AppointmentPage(
                items: testUpcoming,
                page: 0,
                isLast: true,
                totalElements: 2,
              ),
            );

        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();
        expect(find.text('Pediatria'), findsOneWidget);

        // The blip happens DURING the gesture — the most likely moment for
        // one, and the worst possible time to blank the screen.
        fakes.appointments.results[AppointmentScope.upcoming] =
            const Left<Failure, AppointmentPage>(NetworkFailure());
        await pullDown(tester);

        // The appointments the patient was reading are still there, with the
        // failure reported as a line above them instead of replacing them.
        expect(find.text('Pediatria'), findsOneWidget);
        expect(find.text('Reintentar'), findsNothing);
        expect(
          find.textContaining('Sin conexion'),
          findsOneWidget,
        );
      });
    });

    /// `AppointmentCard.actions` is documented as hosting "Reprogramar,
    /// Cancelar" — this is the "Cancelar" half landing.
    group('cancelling an appointment', () {
      void seedUpcoming() {
        fakes.appointments.results[AppointmentScope.upcoming] =
            Right<Failure, AppointmentPage>(
              AppointmentPage(
                items: testUpcoming,
                page: 0,
                isLast: true,
                totalElements: testUpcoming.length,
              ),
            );
      }

      /// Opens the confirmation dialog from the FIRST card and, unless
      /// [confirm] is false, taps the dialog's own "Cancelar turno" — never
      /// the card's, which shares the same label and would tap the wrong
      /// widget type if the finder were not scoped by widget.
      Future<void> tapCancelOnFirstCard(
        WidgetTester tester, {
        bool confirm = true,
      }) async {
        await tester.tap(
          find.widgetWithText(AppButton, 'Cancelar turno').first,
        );
        // The dialog's own enter transition — not one of this app's bespoke
        // animations, so there is no AppMotion constant for it.
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Cancelar este turno?'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(
            TextButton,
            confirm ? 'Cancelar turno' : 'Volver',
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
      }

      testWidgets('an upcoming appointment offers a way to cancel it', (
        tester,
      ) async {
        seedUpcoming();

        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();

        // Both fixture rows are upcoming (pending / waiting) so both offer it.
        expect(
          find.widgetWithText(AppButton, 'Cancelar turno'),
          findsNWidgets(testUpcoming.length),
        );
      });

      testWidgets('declining the confirmation cancels nothing', (
        tester,
      ) async {
        seedUpcoming();

        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();

        await tapCancelOnFirstCard(tester, confirm: false);

        expect(fakes.appointments.cancelCallCount, 0);
        expect(
          find.widgetWithText(AppButton, 'Cancelar turno'),
          findsNWidgets(testUpcoming.length),
        );
      });

      testWidgets("confirming sends the card's own id and reloads the list", (
        tester,
      ) async {
        seedUpcoming();

        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();

        // testUpcoming[0].id is 1 — the appointment's own id, not its
        // position in the list, and not its ticket number (7).
        await tapCancelOnFirstCard(tester);

        expect(fakes.appointments.lastCancelledId, 1);
        // Reloaded on top of the fetch the screen already did on first
        // build — the server, not a local patch, decides the new list.
        expect(
          fakes.appointments.requestedScopes
              .where((scope) => scope == AppointmentScope.upcoming)
              .length,
          greaterThanOrEqualTo(2),
        );
      });

      testWidgets(
        'a cancel failure is reported next to the card, not as an empty list',
        (tester) async {
          seedUpcoming();
          fakes.appointments.cancelResult = const Left<Failure, Appointment>(
            ValidationFailure(
              message: 'No puedes cancelar un turno que ya fue atendido.',
            ),
          );

          await pumpApp(tester, const AppointmentsScreen());
          await tester.pump();

          await tapCancelOnFirstCard(tester);

          expect(
            find.text('No puedes cancelar un turno que ya fue atendido.'),
            findsOneWidget,
          );
          // NOT the load-failure branch: the cards stay, "Reintentar" does
          // not appear. A failed cancel is not a failed load.
          expect(find.text('Pediatria'), findsOneWidget);
          expect(find.text('Reintentar'), findsNothing);
        },
      );
    });

    group('realtime updates', () {
      testWidgets('a server push updates the list without a pull-to-refresh', (
        tester,
      ) async {
        fakes.appointments.results[AppointmentScope.upcoming] =
            Right<Failure, AppointmentPage>(
              AppointmentPage(
                items: testUpcoming,
                page: 0,
                isLast: true,
                totalElements: testUpcoming.length,
              ),
            );

        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();

        expect(find.text('Pediatria'), findsOneWidget);

        // The list changed server-side; nothing on screen asked for it
        // again — the push itself must be what triggers the reload.
        fakes.appointments.results[AppointmentScope.upcoming] =
            const Right<Failure, AppointmentPage>(AppointmentPage.empty());
        fakes.appointments.turnUpdatesController.add(testUpcoming[0]);

        await tester.pump();
        await tester.pump();

        expect(find.text('Pediatria'), findsNothing);
        expect(find.text('No tienes citas agendadas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('leaving the screen stops listening for pushes', (
        tester,
      ) async {
        await pumpApp(tester, const AppointmentsScreen());
        await tester.pump();

        // `_upcoming` subscribes as soon as `AppointmentsScreen` builds it —
        // see `AppointmentsBloc`'s constructor.
        expect(fakes.appointments.turnUpdatesController.hasListener, isTrue);

        // Swaps the whole tree out from under the screen, which runs
        // `State.dispose()` — the same thing that happens for real when the
        // router leaves the authenticated shell on logout.
        await pumpApp(tester, const SizedBox.shrink());

        expect(fakes.appointments.turnUpdatesController.hasListener, isFalse);
      });
    });
  });

  group('LoginScreen', () {
    late FakeAuthRepository repository;

    // The screen resolves its LoginBloc from the service locator, so the
    // locator has to exist. Only the repository is faked — the use cases and
    // the bloc are real, because they are part of what these tests check.
    setUp(() => repository = setUpAuthDependencies());

    testWidgets('renders the hero, both fields and both actions', (
      tester,
    ) async {
      await pumpApp(tester, const LoginScreen());

      // Login's hero is deliberately just the brand row and the tagline: the
      // kicker and the `h1` were removed, and `AuthFormShell.title` is nullable
      // precisely so this screen can omit it.
      expect(
        find.text('Tus citas y tus recetas en un solo lugar.'),
        findsOneWidget,
      );
      expect(find.text('CORREO O CEDULA'), findsOneWidget);
      expect(find.text('CONTRASENA'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the biometric button when the device cannot', (
      tester,
    ) async {
      // The default. A fingerprint button on a device with no sensor, or with
      // no stored session behind it, is an invitation to a dead end.
      repository.canUnlockResult = const Right<Failure, bool>(false);
      await pumpApp(tester, const LoginScreen());

      expect(find.text('Ingresar con huella'), findsNothing);
    });

    testWidgets('shows the biometric button when the device can', (
      tester,
    ) async {
      repository.canUnlockResult = const Right<Failure, bool>(true);
      await pumpApp(tester, const LoginScreen());
      await tester.pump();

      expect(find.text('Ingresar con huella'), findsOneWidget);
    });

    testWidgets('an empty submit reports both fields', (tester) async {
      await pumpApp(tester, const LoginScreen());

      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);

      expect(find.text('Ingresa tu correo o cedula'), findsOneWidget);
      expect(find.text('Ingresa una contrasena'), findsOneWidget);
    });

    testWidgets('the identity field routes to the right validator', (
      tester,
    ) async {
      await pumpApp(tester, const LoginScreen());

      // No `@`, so it is read as a cedula and checked as one.
      await tester.enterText(find.byType(TextFormField).first, '1712345670');
      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);
      expect(find.textContaining('no verifica'), findsOneWidget);

      // With an `@`, the same field is checked as an email.
      await tester.enterText(find.byType(TextFormField).first, 'roto@');
      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);
      expect(find.textContaining('algo no cuadra'), findsOneWidget);
    });

    testWidgets('a cedula is sent as a cedula, an email as an email', (
      tester,
    ) async {
      // The whole point of the single "correo o cedula" field. Sending a
      // cedula in the `email` slot would make AuthService fall through to the
      // wrong lookup and reject a valid patient.
      await pumpApp(tester, const LoginScreen());

      await tester.enterText(find.byType(TextFormField).first, '1712345675');
      await tester.enterText(find.byType(TextFormField).at(1), 'clinica1');
      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);

      expect(repository.lastLoginCedula, '1712345675');
      expect(repository.lastLoginEmail, isNull);

      await tester.enterText(
        find.byType(TextFormField).first,
        'ana@clinica.ec',
      );
      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);

      expect(repository.lastLoginEmail, 'ana@clinica.ec');
      expect(repository.lastLoginCedula, isNull);
    });

    testWidgets('a rejected login surfaces the failure message', (
      tester,
    ) async {
      repository.loginResult = const Left<Failure, AuthSession>(AuthFailure());
      await pumpApp(tester, const LoginScreen());

      await tester.enterText(find.byType(TextFormField).first, '1712345675');
      await tester.enterText(find.byType(TextFormField).at(1), 'clinica1');
      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);
      await tester.pump();

      expect(
        find.text('Correo, cedula o contrasena incorrectos.'),
        findsOneWidget,
      );
    });

    testWidgets('a successful login hands the session to AuthBloc', (
      tester,
    ) async {
      // The screen must NOT navigate. It reports the session and the router's
      // guard decides where a signed-in patient goes.
      final AuthBloc authBloc = await pumpApp(tester, const LoginScreen());

      await tester.enterText(find.byType(TextFormField).first, '1712345675');
      await tester.enterText(find.byType(TextFormField).at(1), 'clinica1');
      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);
      await tester.pump();

      expect(authBloc.state.isAuthenticated, isTrue);
      expect(authBloc.state.session, FakeAuthRepository.testSession);
    });
  });

  group('ProfileScreen', () {
    // The identity card reads the record from the locator now, so the home
    // half has to be registered as well.
    late HomeFakes fakes;
    setUp(() => fakes = setUpHomeDependencies());

    testWidgets('shows every account destination, sign-out included', (
      tester,
    ) async {
      await pumpApp(tester, const ProfileScreen());
      await tester.pump();

      expect(find.text('Mi informacion'), findsOneWidget);
      expect(find.text('Cambiar contrasena'), findsOneWidget);
      expect(find.text('Terminos y condiciones'), findsOneWidget);
      expect(find.text('Politica de privacidad'), findsOneWidget);
      expect(find.text('Cerrar sesion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('derives the avatar initials from the name', (tester) async {
      await pumpApp(tester, const ProfileScreen());
      await tester.pump();

      // 'Ana Perez' -> A + P. The name comes from the record the server
      // returned, not from a placeholder string.
      expect(find.text('AP'), findsOneWidget);
      expect(find.text('Ana Perez'), findsOneWidget);
      expect(find.text('Cedula 1712345678'), findsOneWidget);
    });

    testWidgets('a failed profile load still leaves the way out reachable', (
      tester,
    ) async {
      // The whole point of not gating the screen on the fetch: a patient with
      // no connection must still be able to sign out. Gating the list behind
      // the record would trap them.
      fakes.patient.profileResult = const Left<Failure, PatientProfile>(
        NetworkFailure(),
      );

      await pumpApp(tester, const ProfileScreen());
      await tester.pump();

      expect(find.text('Cerrar sesion'), findsOneWidget);
      expect(find.text('Mi informacion'), findsOneWidget);
    });
  });

  group('HistoryScreen', () {
    late HomeFakes fakes;
    setUp(() => fakes = setUpHomeDependencies());

    void seedAttended(List<Appointment> items) {
      fakes.appointments.results[AppointmentScope.attended] =
          Right<Failure, AppointmentPage>(
            AppointmentPage(
              items: items,
              page: 0,
              isLast: true,
              totalElements: items.length,
            ),
          );
    }

    testWidgets(
      'the card summarises a documented visit and says what is behind the tap',
      (tester) async {
        seedAttended(testAttended);
        fakes.clinical.encountersResult =
            Right<Failure, List<EncounterRecord>>(testEncounters);
        fakes.clinical.prescriptionsResult =
            Right<Failure, List<PrescriptionRecord>>(testPrescriptions);

        await pumpApp(tester, const HistoryScreen());
        await tester.pump();

        // The one clinical line the list carries: it is what a patient scans
        // for when looking for a specific visit.
        expect(find.text('Migrana tensional'), findsOneWidget);

        // Two medications across the fixture's single prescription, counted
        // rather than listed — the count is what tells the patient there is a
        // recipe to open.
        expect(find.text('2 medicamentos'), findsOneWidget);

        // The line items themselves belong to the detail screen. Asserting
        // their ABSENCE here is the whole point of the split: a list that
        // renders every dose is a list nobody can scan.
        expect(find.text('Ibuprofeno'), findsNothing);
        expect(find.text('Paracetamol'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a visit with no documented encounter still shows up, with no '
      'clinical detail',
      (tester) async {
        seedAttended(testAttended);
        fakes.clinical.encountersResult =
            Right<Failure, List<EncounterRecord>>(testEncounters);

        await pumpApp(tester, const HistoryScreen());
        await tester.pump();

        // testAttended[1] (Luis Mora) has no matching encounter fixture.
        // Doctor and date render joined in one Text ("03 may / Luis Mora"),
        // same as `AppointmentsScreen`'s card — see `_EntryCard`.
        expect(find.textContaining('Luis Mora'), findsOneWidget);
        expect(find.text('Migrana tensional'), findsOneWidget);

        // The undocumented visit says so on its own card rather than looking
        // identical to a documented one with a short diagnosis.
        expect(find.text('Sin resumen clinico'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('an empty history reads as empty, not broken', (tester) async {
      seedAttended(const <Appointment>[]);

      await pumpApp(tester, const HistoryScreen());
      await tester.pump();

      expect(find.text('Tu historial esta vacio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a failed load surfaces a message instead of a blank screen',
      (tester) async {
        fakes.appointments.results[AppointmentScope.attended] =
            const Left<Failure, AppointmentPage>(NetworkFailure());

        await pumpApp(tester, const HistoryScreen());
        await tester.pump();

        expect(
          find.text('Sin conexion. Revisa tu internet e intenta de nuevo.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PersonalInfoScreen', () {
    late HomeFakes fakes;
    setUp(() => fakes = setUpHomeDependencies());

    testWidgets(
      'shows the active coverage, distinguishable from a historical one',
      (tester) async {
        fakes.coverage.coveragesResult = Right<Failure, List<CoverageRecord>>(
          <CoverageRecord>[testExpiredCoverage, testActiveCoverage],
        );

        await pumpApp(tester, const PersonalInfoScreen());
        await tester.pump();

        expect(find.text('Activa'), findsOneWidget);
        expect(find.text('Vencida'), findsOneWidget);
        expect(find.text('Seguros Equinoccial'), findsOneWidget);
        expect(find.text('IESS - Plan Basico'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('no coverage on file reads as an honest empty state', (
      tester,
    ) async {
      await pumpApp(tester, const PersonalInfoScreen());
      await tester.pump();

      expect(
        find.textContaining('Todavia no tenes una cobertura'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed coverage load shows a retry, not a crash', (
      tester,
    ) async {
      fakes.coverage.coveragesResult = const Left<Failure, List<CoverageRecord>>(
        NetworkFailure(),
      );

      await pumpApp(tester, const PersonalInfoScreen());
      await tester.pump();

      expect(
        find.text('Sin conexion. Revisa tu internet e intenta de nuevo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppBottomNav', () {
    testWidgets('renders every tab and reports the tapped index', (
      tester,
    ) async {
      int selected = 0;
      await tester.pumpWidget(
        _host(
          Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) => AppBottomNav(
                items: const <AppNavItem>[
                  AppNavItem(label: 'Agendar', icon: Icons.add),
                  AppNavItem(label: 'Mis citas', icon: Icons.list),
                  AppNavItem(label: 'Historial', icon: Icons.history),
                  AppNavItem(label: 'Mi perfil', icon: Icons.person),
                ],
                currentIndex: selected,
                onSelected: (index) => setState(() => selected = index),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Agendar'), findsOneWidget);
      expect(find.text('Mis citas'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Mi perfil'), findsOneWidget);

      await tester.tap(find.text('Historial'));
      await tester.pump(AppMotion.tone);

      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('HistoryDetailScreen', () {
    setUp(setUpHomeDependencies);

    /// The fixture's documented visit, joined the way `HistoryBloc` joins it.
    HistoryEntry documented() => HistoryEntry(
      appointment: testAttended[0],
      encounter: testEncounters[0],
      prescriptions: testPrescriptions,
    );

    testWidgets('renders every prescription line item in full', (tester) async {
      await pumpApp(tester, HistoryDetailScreen(entry: documented()));
      await tester.pump();

      // What the card deliberately does NOT carry — see the HistoryScreen
      // group. Each medication keeps its OWN dose, frequency and duration:
      // collapsing them loses exactly the detail a patient needs to take the
      // drug correctly.
      expect(find.text('Ibuprofeno'), findsOneWidget);
      expect(find.text('400mg'), findsOneWidget);
      expect(find.text('Cada 8 horas'), findsOneWidget);
      expect(find.text('5 dias'), findsOneWidget);
      expect(find.text('Tomar con alimentos'), findsOneWidget);

      expect(find.text('Paracetamol'), findsOneWidget);
      expect(find.text('500mg'), findsOneWidget);
      expect(find.text('Cada 6 horas'), findsOneWidget);
      expect(find.text('3 dias'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the clinical fields the card cannot fit', (
      tester,
    ) async {
      await pumpApp(tester, HistoryDetailScreen(entry: documented()));
      await tester.pump();

      expect(find.text('Dolor de cabeza persistente'), findsOneWidget);
      expect(find.text('Migrana tensional'), findsOneWidget);
      // The encounter's doctor wins over the turn's — it is who actually
      // wrote the record.
      expect(find.text('Ana Torres'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the ticket number, which lives nowhere else', (
      tester,
    ) async {
      await pumpApp(tester, HistoryDetailScreen(entry: documented()));
      await tester.pump();

      // Once a turn leaves "Mis citas" this is the only screen in the app
      // that still carries the number the waiting room called.
      expect(find.text('Turno'), findsOneWidget);
      expect(find.text(testAttended[0].ticket.toString()), findsOneWidget);
    });

    testWidgets('an undocumented visit says so instead of looking broken', (
      tester,
    ) async {
      await pumpApp(
        tester,
        HistoryDetailScreen(entry: HistoryEntry(appointment: testAttended[1])),
      );
      await tester.pump();

      expect(
        find.textContaining('todavia no tiene resumen clinico'),
        findsOneWidget,
      );
      // The visit's own facts still render — that is the point of opening it.
      //  renders uppercase — same as the wizard's 'PASO 1 DE 4'.
      expect(find.text('LA VISITA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lost hand-off reads as "could not open", never as "gone"', (
      tester,
    ) async {
      // `extra` is in-memory only: a cold start on this URL arrives with
      // null. Telling a patient their visit does not exist would be the same
      // class of lie as an empty state over a failed request.
      await pumpApp(tester, const HistoryDetailScreen(entry: null));
      await tester.pump();

      expect(find.text('No pudimos abrir esta visita'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChangePasswordScreen', () {
    late HomeFakes fakes;
    setUp(() => fakes = setUpHomeDependencies());

    Future<void> fillAndSubmit(
      WidgetTester tester, {
      required String password,
      required String confirm,
    }) async {
      await tester.enterText(find.byType(TextFormField).at(0), password);
      await tester.enterText(find.byType(TextFormField).at(1), confirm);
      await tester.pump();
      await _tapLabel(tester, 'Guardar contrasena', settle: AppMotion.press);
      await tester.pump();
    }

    testWidgets('sends BOTH values, because the server is what compares them', (
      tester,
    ) async {
      await pumpApp(tester, const ChangePasswordScreen());
      await tester.pump();

      await fillAndSubmit(tester, password: 'nueva1234', confirm: 'nueva1234');

      expect(fakes.patient.lastPasswordChange?.password, 'nueva1234');
      expect(fakes.patient.lastPasswordChange?.repeated, 'nueva1234');
    });

    testWidgets('a mismatch never reaches the network', (tester) async {
      await pumpApp(tester, const ChangePasswordScreen());
      await tester.pump();

      await fillAndSubmit(tester, password: 'nueva1234', confirm: 'otra12345');

      // The server would answer 400 for this, but making the patient wait for
      // a round trip to learn they mistyped is the wrong shape of feedback.
      expect(fakes.patient.lastPasswordChange, isNull);
      expect(find.text('Las contrasenas no coinciden'), findsOneWidget);
    });

    testWidgets('a password below the rules never reaches the network', (
      tester,
    ) async {
      await pumpApp(tester, const ChangePasswordScreen());
      await tester.pump();

      await fillAndSubmit(tester, password: 'corta', confirm: 'corta');

      expect(fakes.patient.lastPasswordChange, isNull);
      expect(find.text('Al menos 8 caracteres'), findsWidgets);
    });

    testWidgets('a rejected change shows the SERVER message on the form', (
      tester,
    ) async {
      fakes.patient.passwordResult = const Left<Failure, Unit>(
        ValidationFailure(message: 'La contrasena ya fue usada'),
      );

      await pumpApp(tester, const ChangePasswordScreen());
      await tester.pump();

      await fillAndSubmit(tester, password: 'nueva1234', confirm: 'nueva1234');

      // Next to the fields it belongs to, not as a snackbar that slides away
      // before it is read.
      expect(find.text('La contrasena ya fue usada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('there is no "contrasena actual" field to fake safety with', (
      tester,
    ) async {
      await pumpApp(tester, const ChangePasswordScreen());
      await tester.pump();

      // `ChangePasswordBody` has nowhere to put it and the controller
      // verifies nothing beyond the token, so a field here would be theatre.
      // See `ApiEndpoints.patientChangePassword`.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('actual'), findsNothing);
    });
  });
}
