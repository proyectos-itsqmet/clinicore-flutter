import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/patient_registration.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/biometric_data_source.dart';

/// The translation layer.
///
/// This class has exactly one job that nothing else does: turn the data
/// layer's exceptions into `Failure`s. It is the LAST place a `catch` on an
/// [AppException] may appear — if one shows up in a bloc, this boundary has
/// been bypassed and the UI is now coupled to Dio.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.biometrics,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final BiometricDataSource biometrics;

  @override
  Future<Either<Failure, AuthSession>> loginPatient({
    String? email,
    String? cedula,
    required String password,
  }) async {
    return _guard(() async {
      final RemoteAuthResult result = await remote.loginPatient(
        email: email,
        cedula: cedula,
        password: password,
      );

      await local.saveSession(token: result.token, user: result.response);

      return AuthSession(user: result.response.toEntity(), token: result.token);
    });
  }

  @override
  Future<Either<Failure, Unit>> initRegistration({
    required String email,
    required String cedula,
  }) async {
    return _guard(() async {
      final String flashToken = await remote.initRegistration(
        email: email,
        cedula: cedula,
      );

      // The flash token has to be stored, because it is what the interceptor
      // will attach to `register-patient` — that call is authenticated, and
      // the token is the only proof step 1 happened. It carries the authority
      // `ROLE_OTP_PENDING` and dies in 300 seconds.
      //
      // Stored WITHOUT a profile on purpose: `readSession` returns null unless
      // both halves are present, so an abandoned sign-up cannot masquerade as
      // a logged-in user.
      await local.saveTokenOnly(flashToken);

      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> verifyRegistrationOtp({
    required String otp,
  }) async {
    return _guard(() async {
      final String verifiedToken = await remote.verifyRegistrationOtp(otp: otp);

      // Overwrites step 1's token, same as the recovery flow: the
      // OTP_PENDING one has done its job, and keeping both would leave the
      // interceptor a choice it has no way to make.
      //
      // `saveTokenOnly` and not `saveSession` — there is still no patient to
      // store. This is a flash token, not a session.
      await local.saveTokenOnly(verifiedToken);

      return unit;
    });
  }

  @override
  Future<Either<Failure, AuthSession>> completeRegistration(
    PatientRegistration registration,
  ) async {
    return _guard(() async {
      final RemoteAuthResult result = await remote.completeRegistration(
        registration,
      );

      // `register-patient` normally returns a fresh 24h token. If the cookie
      // was missing, keep the flash token rather than dropping the account
      // the user just created — they are registered either way, and the worst
      // case is having to sign in again in a few minutes.
      final String token = result.token.isNotEmpty
          ? result.token
          : (await local.readToken() ?? '');

      if (token.isEmpty) {
        // Registered, but with no usable session. Better to say so than to
        // land on a dashboard where nothing loads.
        throw const ServerException(
          message:
              'Tu cuenta quedo creada, pero no pudimos iniciar la sesion. '
              'Ingresa con tu correo y contrasena.',
        );
      }

      await local.saveSession(token: token, user: result.response);

      return AuthSession(user: result.response.toEntity(), token: token);
    });
  }

  @override
  Future<Either<Failure, AuthSession?>> restoreSession() async {
    return _guard(() async {
      final StoredSession? stored = await local.readSession();
      if (stored == null) return null;
      return AuthSession(user: stored.user.toEntity(), token: stored.token);
    });
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    // Best-effort and FIRST: whatever `/auth/logout` does, the patient must
    // end up logged out on this device. A network error, a timeout, or the
    // server being down are not reasons to leave "cerrar sesion" looking
    // like it did nothing — so its result is deliberately never reported,
    // and `local.clear()` below always runs regardless of what happens here.
    try {
      await remote.logout();
    } on AppException {
      // Swallowed on purpose. See above.
    }

    await local.clear();
    // Always a success. There is no failure a caller could act on: the local
    // half is unconditional, and a sign-out that can refuse is a trap.
    return const Right<Failure, Unit>(unit);
  }

  @override
  Future<Either<Failure, bool>> canUnlockWithBiometrics() async {
    return _guard(() async {
      // Three conditions, and all three have to hold. The stored-session
      // check is the one people forget: a fingerprint prompt with nothing
      // behind it can only ever fail.
      final StoredSession? stored = await local.readSession();
      if (stored == null) return false;
      return biometrics.isAvailable();
    });
  }

  @override
  Future<Either<Failure, AuthSession>> unlockWithBiometrics() async {
    return _guard(() async {
      final StoredSession? stored = await local.readSession();
      if (stored == null) {
        throw const CacheException(
          message: 'No hay una sesion guardada en este dispositivo.',
        );
      }

      // Prompt FIRST, then hand over the session. The order is the whole
      // security property: reading the token before the check would make the
      // prompt decoration.
      await biometrics.authenticate();

      return AuthSession(user: stored.user.toEntity(), token: stored.token);
    });
  }

  @override
  Future<Either<Failure, Unit>> initPasswordRecovery({
    required String email,
  }) async {
    return _guard(() async {
      final String flashToken = await remote.initPasswordRecovery(email: email);

      // Stored WITHOUT a profile, exactly like the registration flash token:
      // `readSession` returns null unless both halves are present, so a
      // half-finished recovery can never masquerade as a signed-in user.
      await local.saveTokenOnly(flashToken);

      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> verifyRecoveryOtp({required String otp}) async {
    return _guard(() async {
      final String changeToken = await remote.verifyRecoveryOtp(otp: otp);

      // Overwrites step 1's token with step 2's. That is the intent: the
      // OTP_PENDING token has done its job and the CHANGE_PASSWORD one is
      // what step 3 needs, so keeping both would only leave the interceptor a
      // choice it has no way to make.
      await local.saveTokenOnly(changeToken);

      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> changePassword({
    required String password,
    required String repeatedPassword,
  }) async {
    return _guard(() async {
      await remote.changePassword(
        password: password,
        repeatedPassword: repeatedPassword,
      );

      // The change token is spent, and the server has already dropped its
      // cookie. Clearing locally too means the device holds nothing that
      // points at the old password — the patient signs in fresh, which is
      // also the only real proof the new one was stored.
      await local.clear();

      return unit;
    });
  }

  /// Runs [body] and turns anything it throws into a [Failure].
  ///
  /// Every repository method funnels through here so the exception-to-failure
  /// mapping exists once. A per-method try/catch would drift within a week.
  /// Runs [body] through the shared mapper, with ONE override.
  ///
  /// A 400/404 from an auth endpoint can mean two different things and only
  /// this feature can tell them apart: rejected credentials, which must become
  /// a deliberately vague [AuthFailure] (saying WHICH half was wrong is a free
  /// account-enumeration oracle, and in a clinic knowing that a cedula has a
  /// patient record is itself health information), versus a rejected payload,
  /// where the server text is the best thing to show.
  ///
  /// Everything else — network, 401, 5xx, cache, biometrics — is identical
  /// across every repository and lives in `core/error/failure_mapper.dart`.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) {
    return guardFailure<T>(
      body,
      onBadRequest: (BadRequestException exception) =>
          _isLoginRejection(exception)
          ? AuthFailure(debugDetail: exception.message)
          : ValidationFailure(
              message: exception.message,
              debugDetail: 'HTTP ${exception.statusCode}',
            ),
    );
  }

  /// The server answers a bad login with 404 + "Error de autenticación"
  /// (`AuthService.loginPatient`), not 401 — which is why this check exists at
  /// all instead of the mapper's 401 branch catching it.
  bool _isLoginRejection(BadRequestException exception) =>
      exception.statusCode == 404 &&
      exception.message.toLowerCase().contains('autenticaci');
}
