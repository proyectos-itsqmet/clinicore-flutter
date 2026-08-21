import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// The sign-in use cases.
///
/// Grouped by FLOW rather than one class per file. The three below are always
/// read together — a login screen uses all of them — and eight files of
/// twenty lines each hides that relationship behind a directory listing.
/// Split them the day one grows enough to deserve its own file.

/// Signs a patient in with a password.
class LoginPatient implements UseCase<AuthSession, LoginParams> {
  const LoginPatient(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession>> call(LoginParams params) {
    return _repository.loginPatient(
      email: params.email,
      cedula: params.cedula,
      password: params.password,
    );
  }
}

class LoginParams extends Equatable {
  const LoginParams({this.email, this.cedula, required this.password});

  /// Builds the right shape from the single field the screen actually has.
  ///
  /// The login form has one "correo o cedula" input, because a patient
  /// remembers their cedula and may not remember which address they signed up
  /// with. The `@` decides which it is, and that is enough: no cedula contains
  /// one and no email address omits one. Making the user pick from a dropdown
  /// first would be asking them to do the app's work.
  factory LoginParams.fromIdentity({
    required String identity,
    required String password,
  }) {
    final String value = identity.trim();
    return value.contains('@')
        ? LoginParams(email: value, password: password)
        : LoginParams(cedula: value, password: password);
  }

  final String? email;
  final String? cedula;
  final String password;

  @override
  List<Object?> get props => <Object?>[email, cedula, password];

  @override
  String toString() =>
      'LoginParams(email: $email, cedula: $cedula, password: <redacted>)';
}

/// Whether to offer the biometric button at all.
///
/// The login screen asks this on init and hides the button when the answer is
/// no. A fingerprint button on a device with no sensor — or before the patient
/// has ever signed in on it — is an invitation to a dead end.
class CanUnlockWithBiometrics implements UseCase<bool, NoParams> {
  const CanUnlockWithBiometrics(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, bool>> call(NoParams params) {
    return _repository.canUnlockWithBiometrics();
  }
}

/// Unlocks the stored session behind a fingerprint or face check.
///
/// Not a login: no password leaves the device and no request reaches the
/// server. See `AuthRepository.unlockWithBiometrics` for why that matters.
class UnlockWithBiometrics implements UseCase<AuthSession, NoParams> {
  const UnlockWithBiometrics(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession>> call(NoParams params) {
    return _repository.unlockWithBiometrics();
  }
}
