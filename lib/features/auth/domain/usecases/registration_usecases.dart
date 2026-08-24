import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../entities/patient_registration.dart';
import '../repositories/auth_repository.dart';

/// Step 1 of registration: claim an email + cedula and get a code mailed.
///
/// On success the server has also issued a token valid for **300 seconds**
/// that [CompleteRegistration] authenticates with. That deadline is real:
/// past it, step 2 comes back 401 and the flow has to restart from here.
class InitRegistration implements UseCase<Unit, InitRegistrationParams> {
  const InitRegistration(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(InitRegistrationParams params) {
    return _repository.initRegistration(
      email: params.email,
      cedula: params.cedula,
    );
  }
}

class InitRegistrationParams extends Equatable {
  const InitRegistrationParams({required this.email, required this.cedula});

  final String email;
  final String cedula;

  @override
  List<Object?> get props => <Object?>[email, cedula];
}

/// Step 2 of registration: the mailed code.
///
/// No email parameter — the server reads it from step 1's token, so passing it
/// again would create two sources of truth for the one thing the flow hinges
/// on. Same shape as [VerifyRecoveryOtp], and deliberately a SEPARATE use case
/// rather than a shared one with a flag: the two endpoints authorise different
/// things, and a boolean that decides which account operation you are allowed
/// to perform is exactly the wrong place to save a class.
class VerifyRegistrationOtp
    implements UseCase<Unit, VerifyRegistrationOtpParams> {
  const VerifyRegistrationOtp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(VerifyRegistrationOtpParams params) {
    return _repository.verifyRegistrationOtp(otp: params.otp);
  }
}

class VerifyRegistrationOtpParams extends Equatable {
  const VerifyRegistrationOtpParams({required this.otp});

  final String otp;

  @override
  List<Object?> get props => <Object?>[otp];

  @override
  String toString() => 'VerifyRegistrationOtpParams(otp: <redacted>)';
}

/// Step 3 of registration. Creates the patient and returns them signed in.
///
/// Takes [PatientRegistration] directly instead of a params wrapper, because
/// that entity IS the parameter object — wrapping it would add a class whose
/// only job is to forward eleven fields.
class CompleteRegistration
    implements UseCase<AuthSession, PatientRegistration> {
  const CompleteRegistration(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession>> call(PatientRegistration params) {
    return _repository.completeRegistration(params);
  }
}
