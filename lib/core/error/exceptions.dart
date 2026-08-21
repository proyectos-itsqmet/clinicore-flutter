/// Data-layer exceptions.
///
/// These exist so a data source can say what happened without knowing what
/// the UI will do about it. The repository is the ONLY place that catches
/// them, and it turns each one into a `Failure`. Nothing above the repository
/// should ever see or catch one of these — if a `catch (e)` on an exception
/// type appears in a bloc, the translation layer has been skipped.
sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode, this.data});

  final String message;
  final int? statusCode;

  /// The raw decoded body, when there was one. Used to pull the server's own
  /// `{"message": "..."}` out for validation errors.
  final Object? data;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// No connection, DNS failure, or a timeout.
///
/// [data] carries Dio's own description of the cause when there is one, so a
/// log can say "SocketException: Connection refused" while the user is shown
/// [message].
class NetworkException extends AppException {
  const NetworkException({required super.message, super.data});
}

/// 5xx, or a 2xx whose body we could not read.
class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode, super.data});
}

/// 401 or 403.
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    required super.message,
    super.statusCode,
    super.data,
  });
}

/// 400 / 404 / 409 — the request was understood and refused. The QMS backend
/// answers this class of error with `{"message": "..."}` (see
/// `Helper.getResponseMessage`), which is why [data] is kept.
class BadRequestException extends AppException {
  const BadRequestException({
    required super.message,
    super.statusCode,
    super.data,
  });
}

/// Secure storage read/write failure.
class CacheException extends AppException {
  const CacheException({required super.message});
}

/// The platform has no biometric hardware, none enrolled, or the user
/// dismissed the prompt.
class BiometricException extends AppException {
  const BiometricException({required super.message});
}
