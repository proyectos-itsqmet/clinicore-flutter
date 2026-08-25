import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Reads the session stored on this device.
///
/// `Right(null)` means nobody is signed in. That is NOT a failure — it is the
/// normal state on a fresh install, and modelling it as an error would force
/// every caller to handle something that is not wrong.
class RestoreSession implements UseCase<AuthSession?, NoParams> {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession?>> call(NoParams params) {
    return _repository.restoreSession();
  }
}

/// Forgets the session on this device and asks the server to drop it too.
///
/// The server round trip (`POST /auth/logout`) is best-effort — see
/// `AuthRepositoryImpl.signOut`. A patient tapping "cerrar sesion" ends up
/// logged out on THIS device no matter what the network does.
class SignOut implements UseCase<Unit, NoParams> {
  const SignOut(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) {
    return _repository.signOut();
  }
}
