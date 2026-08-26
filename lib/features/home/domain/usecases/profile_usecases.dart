import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

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

/// Sets a new password for the patient who is ALREADY signed in.
///
/// Deliberately not called `ChangePassword`: that name is taken by the last
/// step of the password RECOVERY flow
/// (`features/auth/domain/usecases/password_reset_usecases.dart`), and
/// `injection.dart` imports both files. Two use cases named the same in one
/// import scope is a compile error at best and a silently wrong registration
/// at worst.
///
/// The two are not variants of each other, either. Recovery runs without a
/// session, authorises with a 300-second `ROLE_CHANGE_PASSWORD` token, and
/// ends by clearing it so the patient must sign in again. This one runs
/// inside a live session, authorises with the ordinary 24h login token, and
/// leaves that session standing.
class ChangeMyPassword implements UseCase<Unit, ChangeMyPasswordParams> {
  const ChangeMyPassword(this._repository);

  final PatientRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ChangeMyPasswordParams params) {
    return _repository.changeMyPassword(
      password: params.password,
      repeatedPassword: params.repeatedPassword,
    );
  }
}

class ChangeMyPasswordParams extends Equatable {
  const ChangeMyPasswordParams({
    required this.password,
    required this.repeatedPassword,
  });

  final String password;
  final String repeatedPassword;

  @override
  List<Object?> get props => <Object?>[password, repeatedPassword];

  /// Overridden so a password never reaches a log through a bloc transition
  /// or an error report — the same guard `ChangePasswordParams` carries.
  @override
  String toString() => 'ChangeMyPasswordParams(<redacted>)';
}
