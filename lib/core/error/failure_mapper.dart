import 'package:dartz/dartz.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Turns the data layer's exceptions into the domain's failures.
///
/// ## Why this is shared and not copied per repository
///
/// Every repository in this app does the same three things: run the data
/// source, catch [AppException], return a [Failure]. The first repository
/// wrote that out by hand, the second one copied it, and the third is where
/// one of the copies quietly forgets a branch — most likely
/// [UnauthorizedException], which is the one that decides whether the router
/// kicks the user back to login.
///
/// ## The one branch that legitimately differs
///
/// [BadRequestException] means different things in different features. On
/// login, a 400 is "wrong password" and has to become an [AuthFailure] with a
/// deliberately vague message. Everywhere else a 400 is a rejected payload and
/// the server's own text is the best thing to show. That is what
/// [onBadRequest] is for — an override for the one branch that is contextual,
/// instead of a second copy of the whole mapping.
///
/// [UnauthorizedException] is NOT contextual and deliberately has no override:
/// a 401 always means the token is gone or expired, and always means the UI
/// should send the patient to login rather than show an error and stay put.
Failure mapExceptionToFailure(
  AppException exception, {
  Failure Function(BadRequestException)? onBadRequest,
}) {
  return switch (exception) {
    NetworkException() => NetworkFailure(
      message: exception.message,
      debugDetail: exception.data?.toString(),
    ),

    UnauthorizedException() => SessionExpiredFailure(
      debugDetail: exception.message,
    ),

    BadRequestException() =>
      onBadRequest?.call(exception) ??
          ValidationFailure(
            message: exception.message,
            debugDetail: 'HTTP ${exception.statusCode}',
          ),

    ServerException() => ServerFailure(
      message: exception.message,
      statusCode: exception.statusCode,
      debugDetail: exception.data?.toString(),
    ),

    CacheException() => CacheFailure(debugDetail: exception.message),

    BiometricException() => BiometricFailure(message: exception.message),
  };
}

/// Runs [body] and converts anything it throws into a [Failure].
///
/// The `catch (error)` at the bottom is not defensive padding: nothing should
/// reach it, because data sources only throw [AppException]. If something
/// does, it is a bug in the data layer rather than something the patient did,
/// so it gets the generic message and the detail goes to the log — never to
/// the screen.
Future<Either<Failure, T>> guardFailure<T>(
  Future<T> Function() body, {
  Failure Function(BadRequestException)? onBadRequest,
}) async {
  try {
    return Right<Failure, T>(await body());
  } on AppException catch (exception) {
    return Left<Failure, T>(
      mapExceptionToFailure(exception, onBadRequest: onBadRequest),
    );
  } catch (error, stackTrace) {
    return Left<Failure, T>(ServerFailure(debugDetail: '$error\n$stackTrace'));
  }
}
