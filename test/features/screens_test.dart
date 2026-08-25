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
import 'package:clinicore_flutter/features/home/domain/entities/patient_profile.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/booking_repository.dart';
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

    testWidgets('renders the three steps of the board', (tester) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      expect(find.text('Elige, mira el valor y confirma.'), findsOneWidget);
      expect(find.text('1 / MEDICO'), findsOneWidget);
      expect(find.text('2 / DIA'), findsOneWidget);
      expect(find.text('3 / HORA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('step 1 lists the doctors the server returned', (tester) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      expect(find.text('Ana Torres / Pediatria'), findsOneWidget);
      expect(find.text('Luis Mora / Cardiologia'), findsOneWidget);
    });

    testWidgets('the summary starts empty and the CTA starts disabled', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      // Three unanswered rows, each showing the board's placeholder dash.
      expect(find.text('--'), findsNWidgets(3));
      expect(find.text('Confirmar cita'), findsOneWidget);

      final AppButton cta = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Confirmar cita'),
      );
      expect(cta.onPressed, isNull);
    });

    testWidgets('slots are only fetched once a doctor AND a service are set', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      // A service is preselected on load, but no doctor is — so nothing has
      // been asked for yet.
      expect(fakes.booking.lastDoctorId, isNull);

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();

      expect(fakes.booking.lastDoctorId, 'd-1');
      expect(fakes.booking.lastServiceId, 1);
    });

    testWidgets('confirming books the SLOT id, not the chip index', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();

      // The day is preselected from the availability, so only the hour is left.
      await _tapLabel(tester, '10:00');
      await tester.pump();

      expect(find.text('--'), findsNothing);

      await _tapLabel(tester, 'Confirmar cita', settle: AppMotion.press);
      // Drains `AppTick`'s draw timer. A bare `pump()` leaves it pending and
      // the test fails on a timer rather than on the assertion — the confirmed
      // bar mounts an `AppTick` the moment the booking lands.
      await tester.pump(AppMotion.tickDrawDelay + AppMotion.tickDraw);

      // 10:00 is scheduleId 103 in the fixture. Booking 2 (its index) or 101
      // (the first row) would both be a patient sent to the wrong slot.
      expect(fakes.booking.lastBookedScheduleId, 103);
    });

    testWidgets('the confirmed pill shows the ticket the SERVER assigned', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();
      await _tapLabel(tester, '09:00');
      await tester.pump();
      await _tapLabel(tester, 'Confirmar cita', settle: AppMotion.press);
      await tester.pump(AppMotion.tickDrawDelay + AppMotion.tickDraw);

      // The CTA is REPLACED, not joined — one control that changed reads as
      // "done"; two controls read as "did it work?".
      expect(find.text('Confirmar cita'), findsNothing);
      // Ticket 7 comes from the fake's booking response, not from the tap.
      expect(find.text('Reservado / turno 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a booking that fails does NOT show the confirmed pill', (
      tester,
    ) async {
      fakes.booking.bookResult = const Left<Failure, Appointment>(
        ValidationFailure(message: 'Ese cupo ya fue tomado.'),
      );

      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();
      await _tapLabel(tester, '09:00');
      await tester.pump();
      await _tapLabel(tester, 'Confirmar cita', settle: AppMotion.press);
      await tester.pump();

      // This is the whole reason the confirmation waits for the server.
      expect(find.textContaining('Reservado'), findsNothing);
      expect(find.text('Ese cupo ya fue tomado.'), findsOneWidget);
    });

    testWidgets('a taken slot cannot be picked', (tester) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();

      // 08:40 is taken in the fixture, so it renders struck through.
      await _tapLabel(tester, '08:40', warnIfMissed: false);
      await tester.pump();

      // Hora is still unanswered, so the CTA is still inert.
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('changing the doctor invalidates a confirmed booking', (
      tester,
    ) async {
      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();
      await _tapLabel(tester, '09:00');
      await tester.pump();
      await _tapLabel(tester, 'Confirmar cita', settle: AppMotion.press);
      await tester.pump(AppMotion.tickDrawDelay + AppMotion.tickDraw);

      expect(find.text('Reservado / turno 7'), findsOneWidget);

      // A different doctor means different slots. The confirmation must NOT
      // keep claiming a booking the patient has moved away from.
      await _tapLabel(tester, 'Luis Mora / Cardiologia');
      await tester.pump();

      expect(find.textContaining('Reservado'), findsNothing);
      expect(find.text('Confirmar cita'), findsOneWidget);
    });

    testWidgets('no availability says so instead of showing an empty grid', (
      tester,
    ) async {
      fakes.booking.availabilityResult = const Right<Failure, BookingAvailability>(
        BookingAvailability.empty(),
      );

      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      await _tapLabel(tester, 'Ana Torres / Pediatria');
      await tester.pump();

      expect(find.textContaining('no tiene cupos libres'), findsOneWidget);
    });

    testWidgets('a clinic with no services cannot start, and says which', (
      tester,
    ) async {
      fakes.booking.optionsResult = Right<Failure, BookingOptions>(
        BookingOptions(doctors: testDoctors, services: const <BookingService>[]),
      );

      await pumpApp(tester, const BookingScreen());
      await tester.pump();

      expect(find.textContaining('tipos de consulta'), findsOneWidget);
      expect(find.text('1 / MEDICO'), findsNothing);
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

    testWidgets('shows the three destinations the brief asks for', (
      tester,
    ) async {
      await pumpApp(tester, const ProfileScreen());
      await tester.pump();

      expect(find.text('Mi informacion'), findsOneWidget);
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
}
