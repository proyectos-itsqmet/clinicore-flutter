import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
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
    await local.clear();
    // Always a success. There is no server call to fail, and a sign-out that
    // can refuse is a trap.
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
  Future<Either<Failure, Unit>> requestPasswordReset({
    required String email,
  }) async {
    // Not a `_guard` call: the remote data source throws a generic
    // BadRequestException for this, and mapping it through `_mapException`
    // would produce "no pudimos procesar la solicitud" — technically true and
    // completely unhelpful. The user needs to know the feature does not exist
    // yet and what to do instead.
    return const Left<Failure, Unit>(NotImplementedOnServerFailure());
  }

  @override
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    return const Left<Failure, Unit>(NotImplementedOnServerFailure());
  }

  /// Runs [body] and turns anything it throws into a [Failure].
  ///
  /// Every repository method funnels through here so the exception-to-failure
  /// mapping exists once. A per-method try/catch would drift within a week.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right<Failure, T>(await body());
    } on AppException catch (exception) {
      return Left<Failure, T>(_mapException(exception));
    } catch (error, stackTrace) {
      // Nothing should reach here. If something does, it is a bug in the data
      // layer rather than a condition the user caused, so it gets the generic
      // message and the detail goes to the log.
      return Left<Failure, T>(
        ServerFailure(debugDetail: '$error\n$stackTrace'),
      );
    }
  }

  Failure _mapException(AppException exception) {
    return switch (exception) {
      NetworkException() => NetworkFailure(
        message: exception.message,
        debugDetail: exception.data?.toString(),
      ),

      // A real 401/403 means the token is gone or expired — the flash token
      // ran out mid-registration, or a 24h session lapsed. The UI has to go
      // back to login for these, not show an error and stay put.
      UnauthorizedException() => SessionExpiredFailure(
        debugDetail: exception.message,
      ),

      // Rejected credentials arrive HERE, not above — see [_isLoginRejection].
      BadRequestException() =>
        _isLoginRejection(exception)
            ? AuthFailure(debugDetail: exception.message)
            : ValidationFailure(
                message: exception.message,
                debugDetail: 'HTTP ${exception.statusCode}',
              ),

      ServerException() => ServerFailure(
        message: exception.message,
        statusCode: exception.statusCode,
        debugDetail: exception.data?.toString(),
      ),

      CacheException() => CacheFailure(debugDetail: exception.message),

      BiometricException() => BiometricFailure(message: exception.message),
    };
  }

  /// Recognises a rejected credential.
  ///
  /// `AuthService.loginPatient` answers a wrong password with **404 and
  /// "Error de autenticación"** — not 401:
  ///
  /// ```java
  /// } catch (RuntimeException e) {
  ///   return AuthResult.error("Error de autenticación", HttpStatus.NOT_FOUND);
  /// }
  /// ```
  ///
  /// So a 404 from the login endpoint is a bad password, not a missing route,
  /// and it lands in [BadRequestException] rather than
  /// [UnauthorizedException]. Both halves of the test are needed: the status
  /// alone would also match a genuinely absent endpoint, and the message
  /// alone would be a substring match on free-form server text.
  bool _isLoginRejection(BadRequestException exception) =>
      exception.statusCode == 404 &&
      exception.message.toLowerCase().contains('autenticaci');
}
