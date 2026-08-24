import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/patient_profile.dart';
import '../repositories/patient_repository.dart';

/// Reads the signed-in patient's own record.
///
/// Takes [NoParams] because there is nothing to ask for: the server resolves
/// the patient from the token. Passing a UUID here would let a caller ask for
/// somebody else's record, which is a request the server would refuse anyway —
/// better that the type makes it unthinkable.
class GetMyProfile implements UseCase<PatientProfile, NoParams> {
  const GetMyProfile(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, PatientProfile>> call(NoParams params) {
    return _repository.getMyProfile();
  }
}

/// Updates the patient's contact data.
///
/// The parameter is [PatientContactUpdate] and not [PatientProfile] on
/// purpose: the server ignores identity fields, so a use case that accepted a
/// whole profile would let a caller "save" a new cedula, get a 200 back, and
/// believe it worked.
class UpdateMyContact implements UseCase<PatientProfile, PatientContactUpdate> {
  const UpdateMyContact(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, PatientProfile>> call(PatientContactUpdate params) {
    return _repository.updateMyContact(params);
  }
}
