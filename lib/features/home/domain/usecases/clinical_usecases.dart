import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/clinical_record.dart';
import '../repositories/clinical_repository.dart';

/// Reads every documented visit for the signed-in patient.
///
/// Takes [NoParams] for the same reason `GetMyProfile` does: the server
/// resolves the patient from the token, so there is nothing for a caller to
/// pass, and no way to (accidentally or not) ask for somebody else's.
class GetMyEncounters implements UseCase<List<EncounterRecord>, NoParams> {
  const GetMyEncounters(this._repository);

  final ClinicalRepository _repository;

  @override
  Future<Either<Failure, List<EncounterRecord>>> call(NoParams params) {
    return _repository.getMyEncounters();
  }
}

/// Reads every prescription issued to the signed-in patient.
class GetMyPrescriptions
    implements UseCase<List<PrescriptionRecord>, NoParams> {
  const GetMyPrescriptions(this._repository);

  final ClinicalRepository _repository;

  @override
  Future<Either<Failure, List<PrescriptionRecord>>> call(NoParams params) {
    return _repository.getMyPrescriptions();
  }
}
