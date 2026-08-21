import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/patient_registration.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/login_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/registration_usecases.dart';
import 'package:clinicore_flutter/features/auth/domain/usecases/session_usecases.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/auth/auth_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:clinicore_flutter/features/auth/presentation/blocs/registration/registration_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  AuthBloc buildAuthBloc() => AuthBloc(
    restoreSession: RestoreSession(repository),
    signOut: SignOut(repository),
  );

  LoginBloc buildLoginBloc() => LoginBloc(
    loginPatient: LoginPatient(repository),
    canUnlockWithBiometrics: CanUnlockWithBiometrics(repository),
    unlockWithBiometrics: UnlockWithBiometrics(repository),
  );

  RegistrationBloc buildRegistrationBloc() => RegistrationBloc(
    initRegistration: InitRegistration(repository),
    completeRegistration: CompleteRegistration(repository),
  );

  group('AuthBloc', () {
    test('starts unknown, so the router can hold the splash', () {
      // The state that stops the login form flashing at a patient who IS
      // signed in.
      final AuthBloc bloc = buildAuthBloc();
      expect(bloc.state.status, AuthStatus.unknown);
      expect(bloc.state.isResolved, isFalse);
      bloc.close();
    });

    test('no stored session resolves to unauthenticated', () async {
      final AuthBloc bloc = buildAuthBloc()..add(const AuthStarted());
      await expectLater(
        bloc.stream,
        emits(
          predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
        ),
      );
      await bloc.close();
    });

    test('a stored session resolves to authenticated', () async {
      repository.restoreSessionResult = Right<Failure, AuthSession?>(
        FakeAuthRepository.testSession,
      );

      final AuthBloc bloc = buildAuthBloc()..add(const AuthStarted());
      await expectLater(
        bloc.stream,
        emits(predicate<AuthState>((s) => s.isAuthenticated)),
      );
      await bloc.close();
    });

    test(
      'a storage failure resolves to unauthenticated, not to an error',
      () async {
        // There is nothing the patient can do about a keychain error on launch,
        // and the recovery is the same either way: show login.
        repository.restoreSessionResult = const Left<Failure, AuthSession?>(
          CacheFailure(),
        );

        final AuthBloc bloc = buildAuthBloc()..add(const AuthStarted());
        await expectLater(
          bloc.stream,
          emits(
            predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
          ),
        );
        await bloc.close();
      },
    );

    test('signing out clears the stored session too', () async {
      final AuthBloc bloc = buildAuthBloc()
        ..add(AuthSessionGranted(FakeAuthRepository.testSession));
      await bloc.stream.first;

      bloc.add(const AuthSignOutRequested());
      await expectLater(
        bloc.stream,
        emits(
          predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
        ),
      );

      // Not just the in-memory state: a token the server has stopped honouring
      // must not survive on the device.
      expect(repository.signOutCount, 1);
      await bloc.close();
    });

    test('an expired session is treated exactly like a sign-out', () async {
      final AuthBloc bloc = buildAuthBloc()
        ..add(AuthSessionGranted(FakeAuthRepository.testSession));
      await bloc.stream.first;

      bloc.add(const AuthSessionExpired());
      await bloc.stream.first;

      expect(bloc.state.status, AuthStatus.unauthenticated);
      expect(repository.signOutCount, 1);
      await bloc.close();
    });
  });

  group('LoginBloc', () {
    test('splits the identity field by the @', () async {
      final LoginBloc bloc = buildLoginBloc()
        ..add(
          const LoginSubmitted(identity: '1712345675', password: 'clinica1'),
        );
      await bloc.stream.firstWhere((s) => s.status == LoginStatus.success);

      expect(repository.lastLoginCedula, '1712345675');
      expect(repository.lastLoginEmail, isNull);
      await bloc.close();
    });

    test('trims the identity before sending it', () async {
      // A pasted address usually arrives with a trailing space, and the server
      // would reject it as an invalid email.
      final LoginBloc bloc = buildLoginBloc()
        ..add(
          const LoginSubmitted(
            identity: '  ana@clinica.ec  ',
            password: 'clinica1',
          ),
        );
      await bloc.stream.firstWhere((s) => s.status == LoginStatus.success);

      expect(repository.lastLoginEmail, 'ana@clinica.ec');
      await bloc.close();
    });

    test('a rejection lands in failure with the message intact', () async {
      repository.loginResult = const Left<Failure, AuthSession>(AuthFailure());

      final LoginBloc bloc = buildLoginBloc()
        ..add(const LoginSubmitted(identity: 'a@b.ec', password: 'x'));
      final LoginState state = await bloc.stream.firstWhere(
        (s) => s.status == LoginStatus.failure,
      );

      expect(state.failure, isA<AuthFailure>());
      expect(state.session, isNull);
      await bloc.close();
    });

    test('dismissing the failure clears it, so it cannot reappear', () async {
      repository.loginResult = const Left<Failure, AuthSession>(AuthFailure());

      final LoginBloc bloc = buildLoginBloc()
        ..add(const LoginSubmitted(identity: 'a@b.ec', password: 'x'));
      await bloc.stream.firstWhere((s) => s.status == LoginStatus.failure);

      bloc.add(const LoginFailureDismissed());
      final LoginState state = await bloc.stream.firstWhere(
        (s) => s.status == LoginStatus.idle,
      );

      expect(state.failure, isNull);
      await bloc.close();
    });

    test('biometric unlock produces a session without a password', () async {
      final LoginBloc bloc = buildLoginBloc()
        ..add(const LoginBiometricRequested());
      final LoginState state = await bloc.stream.firstWhere(
        (s) => s.status == LoginStatus.success,
      );

      expect(state.session, FakeAuthRepository.testSession);
      // The whole security property: no credential was replayed.
      expect(repository.lastLoginPassword, isNull);
      await bloc.close();
    });
  });

  group('RegistrationBloc', () {
    test('walks identity -> verification -> profile -> done', () async {
      final RegistrationBloc bloc = buildRegistrationBloc();
      expect(bloc.state.step, RegistrationStep.identity);

      bloc.add(
        const RegistrationIdentitySubmitted(
          email: 'ana@clinica.ec',
          cedula: '1712345675',
        ),
      );
      await bloc.stream.firstWhere(
        (s) => s.step == RegistrationStep.verification,
      );

      bloc.add(const RegistrationCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.profile);

      bloc.add(
        RegistrationProfileSubmitted(
          firstName: 'Ana',
          lastName: 'Nunez',
          birthday: DateTime(1990, 3, 7),
          password: 'clinica1',
        ),
      );
      final RegistrationState done = await bloc.stream.firstWhere(
        (s) => s.step == RegistrationStep.done,
      );

      expect(done.session, FakeAuthRepository.testSession);
      await bloc.close();
    });

    test('carries the step-1 email and cedula into step 3', () async {
      // AuthService.completeRegistration rejects the call if the email does
      // not match the flash token's subject, so losing this pair between
      // screens is a guaranteed failure at the last step.
      final RegistrationBloc bloc = buildRegistrationBloc()
        ..add(
          const RegistrationIdentitySubmitted(
            email: 'ana@clinica.ec',
            cedula: '1712345675',
          ),
        );
      await bloc.stream.firstWhere(
        (s) => s.step == RegistrationStep.verification,
      );

      bloc.add(const RegistrationCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.profile);

      bloc.add(
        RegistrationProfileSubmitted(
          firstName: 'Ana',
          lastName: 'Nunez',
          birthday: DateTime(1990, 3, 7),
          password: 'clinica1',
          gender: Gender.female,
          phone: '0991234567',
        ),
      );
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.done);

      final PatientRegistration? sent = repository.lastRegistration;
      expect(sent?.email, 'ana@clinica.ec');
      expect(sent?.cedula, '1712345675');
      expect(sent?.gender, Gender.female);
      expect(sent?.phone, '0991234567');
      await bloc.close();
    });

    test('a rejected identity stays on step 1', () async {
      // "El usuario ya se encuentra registrado con esta cedula" — the patient
      // must not be walked forward into a flow that cannot complete.
      repository.initRegistrationResult = const Left<Failure, Unit>(
        ValidationFailure(
          message: 'El usuario ya se encuentra registrado con esta cedula',
        ),
      );

      final RegistrationBloc bloc = buildRegistrationBloc()
        ..add(
          const RegistrationIdentitySubmitted(
            email: 'ana@clinica.ec',
            cedula: '1712345675',
          ),
        );
      final RegistrationState state = await bloc.stream.firstWhere(
        (s) => s.status == RegistrationStatus.failure,
      );

      expect(state.step, RegistrationStep.identity);
      expect(state.failure?.message, contains('ya se encuentra registrado'));
      await bloc.close();
    });

    test(
      'resending re-runs step 1, which is what refreshes the token',
      () async {
        final RegistrationBloc bloc = buildRegistrationBloc()
          ..add(
            const RegistrationIdentitySubmitted(
              email: 'ana@clinica.ec',
              cedula: '1712345675',
            ),
          );
        await bloc.stream.firstWhere(
          (s) => s.step == RegistrationStep.verification,
        );
        expect(repository.initRegistrationCount, 1);

        bloc.add(const RegistrationCodeResendRequested());
        await bloc.stream.firstWhere(
          (s) => s.status == RegistrationStatus.idle,
        );

        expect(repository.initRegistrationCount, 2);
        expect(repository.lastInitEmail, 'ana@clinica.ec');
        await bloc.close();
      },
    );

    test('the 300-second cliff walks the flow back to step 1', () async {
      // The flash token from step 1 expires in five minutes. A patient who
      // took their time on the profile form gets a 401 that has nothing to do
      // with anything they typed — so the bloc restarts the flow with an
      // explanation instead of leaving them on a form that keeps failing.
      final RegistrationBloc bloc = buildRegistrationBloc()
        ..add(
          const RegistrationIdentitySubmitted(
            email: 'ana@clinica.ec',
            cedula: '1712345675',
          ),
        );
      await bloc.stream.firstWhere(
        (s) => s.step == RegistrationStep.verification,
      );
      bloc.add(const RegistrationCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.profile);

      repository.completeRegistrationResult = const Left<Failure, AuthSession>(
        SessionExpiredFailure(),
      );

      bloc.add(
        RegistrationProfileSubmitted(
          firstName: 'Ana',
          lastName: 'Nunez',
          birthday: DateTime(1990, 3, 7),
          password: 'clinica1',
        ),
      );
      final RegistrationState state = await bloc.stream.firstWhere(
        (s) => s.status == RegistrationStatus.failure,
      );

      expect(state.step, RegistrationStep.identity);
      expect(state.failure?.message, contains('Se agoto el tiempo'));
      // And it must NOT say "sesion vencida" on a form for an account that
      // does not exist yet.
      expect(state.failure, isNot(isA<SessionExpiredFailure>()));
      await bloc.close();
    });

    test(
      'submitting a profile with no identity restarts instead of crashing',
      () async {
        // Only reachable by deep-linking straight to the last step.
        final RegistrationBloc bloc = buildRegistrationBloc()
          ..add(
            RegistrationProfileSubmitted(
              firstName: 'Ana',
              lastName: 'Nunez',
              birthday: DateTime(1990, 3, 7),
              password: 'clinica1',
            ),
          );
        final RegistrationState state = await bloc.stream.firstWhere(
          (s) => s.status == RegistrationStatus.failure,
        );

        expect(state.step, RegistrationStep.identity);
        expect(repository.lastRegistration, isNull);
        await bloc.close();
      },
    );
  });
}
