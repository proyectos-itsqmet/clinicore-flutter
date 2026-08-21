import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_session.dart';
import '../entities/patient_registration.dart';

/// What the app can ask of authentication.
///
/// The domain declares this; `data/repositories/auth_repository_impl.dart`
/// satisfies it. Nothing in here mentions Dio, JWTs, cookies or secure
/// storage — that is the whole point of the boundary, and it is what lets the
/// blocs be tested without a server.
abstract interface class AuthRepository {
  /// Signs in a patient with EITHER an email or a cedula.
  ///
  /// Exactly one of [email] / [cedula] should be non-null. The server checks
  /// `ci` first and falls back to `email`, so sending both is not an error —
  /// it just means the cedula wins, which is rarely what a caller meant.
  Future<Either<Failure, AuthSession>> loginPatient({
    String? email,
    String? cedula,
    required String password,
  });

  /// Step 1 of registration: claims an email + cedula pair and asks the
  /// server to mail a code.
  ///
  /// Succeeding here also stores a short-lived token that step 2 needs, so
  /// [completeRegistration] must be called within its 5-minute window.
  Future<Either<Failure, Unit>> initRegistration({
    required String email,
    required String cedula,
  });

  /// Step 2 of registration. Returns a full session — the server signs the
  /// new patient in as part of creating them.
  Future<Either<Failure, AuthSession>> completeRegistration(
    PatientRegistration registration,
  );

  /// The session stored on this device, or `null` if there is none.
  ///
  /// Returns `Right(null)` rather than a failure for "nobody is signed in":
  /// that is a normal state on first launch, not an error, and modelling it as
  /// one makes every caller handle a failure that is not one.
  Future<Either<Failure, AuthSession?>> restoreSession();

  /// Forgets the session on this device.
  ///
  /// There is no server call. The QMS token is a stateless JWT and
  /// `AuthController` has no logout route, so logging out IS deleting the
  /// token locally. The consequence is worth being honest about: a token that
  /// leaked stays valid until it expires, up to 24 hours.
  Future<Either<Failure, Unit>> signOut();

  /// Whether this device can unlock with a fingerprint or face.
  ///
  /// False when there is no sensor, nothing enrolled, or no stored session to
  /// unlock — all three are "no", and the caller does not need to know which.
  Future<Either<Failure, bool>> canUnlockWithBiometrics();

  /// Unlocks the stored session behind a biometric prompt.
  ///
  /// **This does not re-authenticate against the server, and that is
  /// deliberate.** The alternative — keeping the patient's password on the
  /// device so it can be replayed — trades a real credential for a
  /// convenience. Here the biometric check gates access to a token that was
  /// already there, so the worst case of a compromised device is unchanged.
  Future<Either<Failure, AuthSession>> unlockWithBiometrics();

  /// Asks the server to start a password reset.
  ///
  /// **Not implemented on the server.** See [ApiEndpoints.forgotPassword] —
  /// the QMS backend has no password recovery at all. This returns
  /// [NotImplementedOnServerFailure] until it does, which is why the screen
  /// can say something true instead of pretending a mail was sent.
  Future<Either<Failure, Unit>> requestPasswordReset({required String email});

  /// Completes a password reset with the emailed code.
  ///
  /// **Not implemented on the server.** See [requestPasswordReset].
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  });
}
