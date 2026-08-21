import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Asks the server to start a password reset.
///
/// **Both use cases in this file currently fail with
/// `NotImplementedOnServerFailure`.** The QMS backend has no password recovery
/// of any kind: `AuthController` exposes login and the two registration steps,
/// and nothing else.
///
/// They exist anyway, and that is a deliberate call rather than dead code. The
/// screen, the bloc, the validation and the wiring are all finished and
/// correct; the only thing missing is two routes on the server. When those
/// ship, the change is three lines in `AuthRemoteDataSource` and nothing else
/// moves. The alternative — leaving the screens unwired — would mean
/// rediscovering this whole flow later.
class RequestPasswordReset
    implements UseCase<Unit, RequestPasswordResetParams> {
  const RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RequestPasswordResetParams params) {
    return _repository.requestPasswordReset(email: params.email);
  }
}

class RequestPasswordResetParams extends Equatable {
  const RequestPasswordResetParams({required this.email});

  final String email;

  @override
  List<Object?> get props => <Object?>[email];
}

/// Sets a new password using the emailed code. See [RequestPasswordReset].
class ConfirmPasswordReset
    implements UseCase<Unit, ConfirmPasswordResetParams> {
  const ConfirmPasswordReset(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ConfirmPasswordResetParams params) {
    return _repository.confirmPasswordReset(
      email: params.email,
      otp: params.otp,
      newPassword: params.newPassword,
    );
  }
}

class ConfirmPasswordResetParams extends Equatable {
  const ConfirmPasswordResetParams({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  final String email;
  final String otp;
  final String newPassword;

  @override
  List<Object?> get props => <Object?>[email, otp, newPassword];

  @override
  String toString() =>
      'ConfirmPasswordResetParams($email, otp: <redacted>, '
      'newPassword: <redacted>)';
}
