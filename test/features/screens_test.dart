import 'package:clinicore_flutter/core/theme/theme.dart';
import 'package:clinicore_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/booking_screen.dart';
import 'package:clinicore_flutter/features/home/presentation/screens/profile_screen.dart';
import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/auth/auth_bloc.dart';
import 'package:clinicore_flutter/shared/ui/organisms/organisms.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_repository.dart';
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
    testWidgets('renders the three steps of the board', (tester) async {
      await tester.pumpWidget(_host(const BookingScreen()));
      await tester.pump();

      expect(find.text('Elige, mira el valor y confirma.'), findsOneWidget);
      expect(find.text('1 / MEDICO'), findsOneWidget);
      expect(find.text('2 / DIA'), findsOneWidget);
      expect(find.text('3 / HORA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the summary starts empty and the CTA starts disabled', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BookingScreen()));
      await tester.pump();

      // Three unanswered rows, each showing the board's placeholder dash.
      expect(find.text('--'), findsNWidgets(3));
      expect(find.text('Confirmar cita'), findsOneWidget);
      expect(find.text('Reservado / 09:00'), findsNothing);
    });

    testWidgets('doctor, day and slot then confirm shows the booked pill', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BookingScreen()));
      await tester.pump();

      await _tapLabel(tester, 'Dr(a). [APELLIDO 1]');
      await _tapLabel(tester, '12', settle: AppMotion.tone);
      await _tapLabel(tester, '09:00');

      // The summary has picked all three up.
      expect(find.text('--'), findsNothing);

      await _tapLabel(tester, 'Confirmar cita', settle: AppMotion.press);
      await tester.pump(AppMotion.tickDrawDelay + AppMotion.tickDraw);

      // The CTA is REPLACED, not joined — one control that changed reads as
      // "done"; two controls read as "did it work?".
      expect(find.text('Confirmar cita'), findsNothing);
      expect(find.text('Reservado / 09:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a taken slot cannot be picked', (tester) async {
      await tester.pumpWidget(_host(const BookingScreen()));
      await tester.pump();

      await _tapLabel(tester, 'Dr(a). [APELLIDO 1]');
      await _tapLabel(tester, '12', settle: AppMotion.tone);

      // 08:40 is struck through in the board's own data.
      await _tapLabel(tester, '08:40', warnIfMissed: false);

      // Hora is still unanswered, so the CTA is still inert.
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('changing a selection invalidates a confirmed booking', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BookingScreen()));
      await tester.pump();

      await _tapLabel(tester, 'Dr(a). [APELLIDO 1]');
      await _tapLabel(tester, '12', settle: AppMotion.tone);
      await _tapLabel(tester, '09:00');
      await _tapLabel(tester, 'Confirmar cita', settle: AppMotion.press);
      await tester.pump(AppMotion.tickDrawDelay + AppMotion.tickDraw);

      expect(find.text('Reservado / 09:00'), findsOneWidget);

      // Pick a different hour: the confirmation must NOT keep claiming a time
      // the user has moved away from.
      await _tapLabel(tester, '10:00');

      expect(find.text('Reservado / 09:00'), findsNothing);
      expect(find.text('Confirmar cita'), findsOneWidget);
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
    setUp(setUpAuthDependencies);

    testWidgets('shows the three destinations the brief asks for', (
      tester,
    ) async {
      await pumpApp(tester, const ProfileScreen());

      expect(find.text('Mi informacion'), findsOneWidget);
      expect(find.text('Terminos y condiciones'), findsOneWidget);
      expect(find.text('Politica de privacidad'), findsOneWidget);
      expect(find.text('Cerrar sesion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('derives the avatar initials from the name', (tester) async {
      await pumpApp(tester, const ProfileScreen());

      // '[NOMBRE DEL PACIENTE]' -> brackets stripped -> N + D.
      expect(find.text('ND'), findsOneWidget);
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
