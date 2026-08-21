import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// One thing the app can do.
///
/// A use case is callable, takes exactly one parameter object, and returns
/// `Either<Failure, T>` — never throws. That uniformity is the point: a bloc
/// can `await useCase(params)` and `fold` the result without knowing whether
/// the work hit the network, the keychain or the biometric sensor.
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// The parameter object for a use case that needs no input.
///
/// `void` cannot be used as a type argument in a way that keeps `call`
/// uniform, so use cases like "restore the session" take this instead.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const <Object?>[];
}
