import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/patient_profile.dart';

/// What the app can ask about the signed-in patient's own record.
///
/// Nothing here mentions Dio, JSON or a UUID: the identity comes from the
/// session, and the data layer is the only place that knows how.
abstract interface class PatientRepository {
  Future<Either<Failure, PatientProfile>> getMyProfile();

  /// Updates ONLY contact data. The parameter type is what enforces that —
  /// see [PatientContactUpdate] for why it is not a whole profile.
  ///
  /// Returns the profile the server ended up with, so a caller that shows the
  /// result is showing what was actually stored rather than what it hoped.
  Future<Either<Failure, PatientProfile>> updateMyContact(
    PatientContactUpdate update,
  );

  /// Sets a new password for the signed-in patient.
  ///
  /// Returns [Unit] and not the profile: a password is not part of
  /// [PatientProfile] and never comes back from the server, so there is
  /// nothing for a caller to render. What it succeeded at is the whole
  /// answer.
  ///
  /// The session survives — the token is stateless and the server only
  /// re-encodes the stored hash, so a patient who changes their password from
  /// inside the app is not signed out. That differs from the RECOVERY flow,
  /// where the server clears the cookie deliberately.
  Future<Either<Failure, Unit>> changeMyPassword({
    required String password,
    required String repeatedPassword,
  });
}
