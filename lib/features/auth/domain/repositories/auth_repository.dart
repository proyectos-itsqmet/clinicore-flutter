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

  /// Step 2 of registration: the mailed code.
  ///
  /// The email is not a parameter — the server reads it from step 1's token,
  /// the same reasoning as [verifyRecoveryOtp].
  ///
  /// **Three wrong codes block the address** and the block is per address, so
  /// recovering from it means going back to [initRegistration], which is what
  /// mails a new code and clears the block.
  ///
  /// Succeeding swaps step 1's token for one that step 3 accepts just as well,
  /// so the flow does not lose its authorisation by verifying.
  Future<Either<Failure, Unit>> verifyRegistrationOtp({required String otp});

  /// Step 3 of registration. Returns a full session — the server signs the
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

  /// Forgets the session on this device, and tells the server too — best
  /// effort.
  ///
  /// Calls `POST /auth/logout` first, but never surfaces its outcome: a
  /// stateless JWT is logged out just as well by deleting it from the
  /// device, so a failed or timed-out call must NOT stop this from clearing
  /// the device. This always returns `Right`. The consequence worth being
  /// honest about is unchanged by any of this: a token that leaked stays
  /// valid server-side until it expires, up to 24 hours, whether or not the
  /// server call above succeeded.
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

  /// Recovery step 1: asks the server to mail a code.
  ///
  /// Succeeding stores a 5-minute token that step 2 needs, so
  /// [verifyRecoveryOtp] has to happen inside that window. The server accepts
  /// the address of a patient, a doctor OR an operator.
  ///
  /// A 404 here means the address is not registered — worth surfacing plainly
  /// rather than hiding, because the alternative is a patient waiting for a
  /// mail that was never going to arrive.
  Future<Either<Failure, Unit>> initPasswordRecovery({required String email});

  /// Recovery step 2: the code from the mail.
  ///
  /// The email is not a parameter: the server reads it from step 1's token.
  /// Succeeding swaps that token for a 10-minute one that authorises the
  /// change itself.
  ///
  /// **Three wrong codes block it** (`OtpData.excedioIntentos`), and the block
  /// is per address, so retrying means going back to step 1.
  Future<Either<Failure, Unit>> verifyRecoveryOtp({required String otp});

  /// Recovery step 3: the new password.
  ///
  /// Sends the repeat too, because the server is what compares them. On
  /// success the token is cleared from the device: the patient signs in again
  /// with the new password, which also proves it was stored.
  Future<Either<Failure, Unit>> changePassword({
    required String password,
    required String repeatedPassword,
  });
}
