import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/coverage.dart';

/// What the app can ask about the signed-in patient's insurance coverage.
abstract interface class CoverageRepository {
  /// Every coverage the patient has held, most recent first — see
  /// `PatientCoverageService.listForPatient`'s own ordering
  /// (`findByPatientUuidOrderByValidFromDesc`). At most one entry has
  /// [CoverageRecord.active] true.
  Future<Either<Failure, List<CoverageRecord>>> getMyCoverages();
}
