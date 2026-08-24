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
}
