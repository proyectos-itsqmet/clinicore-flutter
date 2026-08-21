import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/auth_user.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/patient_registration.dart';
import 'package:clinicore_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

/// A hand-written [AuthRepository] double.
///
/// Hand-written rather than generated with a mocking package, and that is a
/// deliberate choice for a repository this small: the whole interface is ten
/// methods, the double is readable top to bottom, and there is no build step
/// or `when(...).thenReturn(...)` ceremony between a test and what it means.
///
/// Every method is scripted through a public field, so a test says what it
/// wants in one line:
///
/// ```dart
/// repository.loginResult = Left(const AuthFailure());
/// ```
///
/// It also RECORDS what it was called with, which is what lets a test assert
/// that the login screen actually sent the cedula as a cedula and not as an
/// email.
class FakeAuthRepository implements AuthRepository {
  // ---- scripted results ----

  Either<Failure, AuthSession> loginResult = Right(testSession);
  Either<Failure, Unit> initRegistrationResult = const Right<Failure, Unit>(
    unit,
  );
  Either<Failure, AuthSession> completeRegistrationResult = Right(testSession);
  Either<Failure, AuthSession?> restoreSessionResult =
      const Right<Failure, AuthSession?>(null);
  Either<Failure, bool> canUnlockResult = const Right<Failure, bool>(false);
  Either<Failure, AuthSession> unlockResult = Right(testSession);

  // ---- recorded calls ----

  String? lastLoginEmail;
  String? lastLoginCedula;
  String? lastLoginPassword;
  String? lastInitEmail;
  String? lastInitCedula;
  PatientRegistration? lastRegistration;
  int signOutCount = 0;
  int initRegistrationCount = 0;

  /// A session every test can share. Nothing mutates it.
  static final AuthSession testSession = AuthSession(
    user: const AuthUser(
      email: 'paciente@clinica.ec',
      firstName: 'Ana',
      lastName: 'Nunez',
      role: UserRole.patient,
    ),
    token: 'test.jwt.token',
  );

  @override
  Future<Either<Failure, AuthSession>> loginPatient({
    String? email,
    String? cedula,
    required String password,
  }) async {
    lastLoginEmail = email;
    lastLoginCedula = cedula;
    lastLoginPassword = password;
    return loginResult;
  }

  @override
  Future<Either<Failure, Unit>> initRegistration({
    required String email,
    required String cedula,
  }) async {
    lastInitEmail = email;
    lastInitCedula = cedula;
    initRegistrationCount++;
    return initRegistrationResult;
  }

  @override
  Future<Either<Failure, AuthSession>> completeRegistration(
    PatientRegistration registration,
  ) async {
    lastRegistration = registration;
    return completeRegistrationResult;
  }

  @override
  Future<Either<Failure, AuthSession?>> restoreSession() async =>
      restoreSessionResult;

  @override
  Future<Either<Failure, Unit>> signOut() async {
    signOutCount++;
    return const Right<Failure, Unit>(unit);
  }

  @override
  Future<Either<Failure, bool>> canUnlockWithBiometrics() async =>
      canUnlockResult;

  @override
  Future<Either<Failure, AuthSession>> unlockWithBiometrics() async =>
      unlockResult;

  @override
  Future<Either<Failure, Unit>> requestPasswordReset({
    required String email,
  }) async => const Left<Failure, Unit>(NotImplementedOnServerFailure());

  @override
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async => const Left<Failure, Unit>(NotImplementedOnServerFailure());
}
