import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Password recovery, in the three steps the server actually implements.
///
/// The shape mirrors registration for a reason beyond consistency: both flows
/// are a chain of short-lived tokens where each step authorises the next, so
/// each step has to be its own use case. Folding them into one call would mean
/// a single failure could not say WHICH step failed — and "the code was wrong"
/// and "your five minutes ran out" need different recoveries.
///
/// | step                    | window | on success the server issues |
/// |-------------------------|--------|------------------------------|
/// | [InitPasswordRecovery]  | —      | `ROLE_OTP_PENDING`, 300s     |
/// | [VerifyRecoveryOtp]     | 300s   | `ROLE_CHANGE_PASSWORD`, 300s |
/// | [ChangePassword]        | 300s   | nothing; the cookie is cleared |

/// Step 1 — asks the server to mail a 6-digit code.
///
/// The address may belong to a patient, a doctor or an operator; the server
/// checks all three tables. A 404 means it belongs to nobody.
class InitPasswordRecovery
    implements UseCase<Unit, InitPasswordRecoveryParams> {
  const InitPasswordRecovery(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(InitPasswordRecoveryParams params) {
    return _repository.initPasswordRecovery(email: params.email);
  }
}

class InitPasswordRecoveryParams extends Equatable {
  const InitPasswordRecoveryParams({required this.email});

  final String email;

  @override
  List<Object?> get props => <Object?>[email];
}

/// Step 2 — the code.
///
/// No email parameter, and that is not an omission: the server reads it from
/// step 1's token. Passing it again would create two sources of truth for the
/// one thing the whole flow hinges on.
class VerifyRecoveryOtp implements UseCase<Unit, VerifyRecoveryOtpParams> {
  const VerifyRecoveryOtp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(VerifyRecoveryOtpParams params) {
    return _repository.verifyRecoveryOtp(otp: params.otp);
  }
}

class VerifyRecoveryOtpParams extends Equatable {
  const VerifyRecoveryOtpParams({required this.otp});

  final String otp;

  @override
  List<Object?> get props => <Object?>[otp];

  @override
  String toString() => 'VerifyRecoveryOtpParams(otp: <redacted>)';
}

/// Step 3 — the new password.
///
/// Both fields go to the server because the server is what compares them. The
/// form checks it first so the patient hears about a typo before a round trip,
/// but the server's answer is the one that decides.
class ChangePassword implements UseCase<Unit, ChangePasswordParams> {
  const ChangePassword(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ChangePasswordParams params) {
    return _repository.changePassword(
      password: params.password,
      repeatedPassword: params.repeatedPassword,
    );
  }
}

class ChangePasswordParams extends Equatable {
  const ChangePasswordParams({
    required this.password,
    required this.repeatedPassword,
  });

  final String password;
  final String repeatedPassword;

  @override
  List<Object?> get props => <Object?>[password, repeatedPassword];

  @override
  String toString() => 'ChangePasswordParams(<redacted>)';
}
