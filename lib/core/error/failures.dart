import 'package:equatable/equatable.dart';

/// What went wrong, in terms the presentation layer can act on.
///
/// A [Failure] is the LEFT side of every `Either` this app returns. It is
/// deliberately not an exception: exceptions belong to the data layer (see
/// `exceptions.dart`), and the repository's job is to translate them into one
/// of these before anything above it has to care about Dio, HTTP or
/// SocketException.
///
/// Every failure carries a [message] that is safe to show a patient. That is
/// a hard rule: a stack trace, a SQL error or "DioException [connection
/// error]" is not an answer to someone trying to see tomorrow's appointment.
/// Technical detail goes in [debugDetail], which is for logs only.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.debugDetail});

  /// User-facing. Spanish, specific, and about what to do next.
  final String message;

  /// Never shown. For logs and bug reports.
  final String? debugDetail;

  @override
  List<Object?> get props => <Object?>[message, debugDetail];
}

/// The device has no usable connection, or the request timed out.
///
/// Separate from [ServerFailure] because the user can do something about this
/// one, and the app should offer a retry rather than an apology.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Sin conexion. Revisa tu internet e intenta de nuevo.',
    super.debugDetail,
  });
}

/// The server answered, but with 5xx — or with something we cannot parse.
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'El servicio no responde. Intenta en unos minutos.',
    super.debugDetail,
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => <Object?>[...super.props, statusCode];
}

/// The credentials were rejected.
///
/// The message is deliberately vague about WHICH half was wrong. Telling a
/// caller "esa cedula no existe" is a free account-enumeration oracle, and
/// this is a clinic: knowing that a given cedula has a patient record is
/// itself health information.
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Correo, cedula o contrasena incorrectos.',
    super.debugDetail,
  });
}

/// A valid session expired or was revoked. The presentation layer's cue to
/// send the user back to login, not to show an error and stay put.
class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure({
    super.message = 'Tu sesion vencio. Ingresa de nuevo.',
    super.debugDetail,
  });
}

/// The server rejected the payload — a duplicate cedula, a malformed date,
/// a validation error. [message] carries the server's own text when it sent
/// one, because for this class of error the server knows more than we do.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.debugDetail,
    this.fieldErrors,
  });

  /// Field name -> message, when the server itemises. Lets a form highlight
  /// the offending input instead of showing one line at the top.
  final Map<String, String>? fieldErrors;

  @override
  List<Object?> get props => <Object?>[...super.props, fieldErrors];
}

/// The device cannot do biometrics, or the user cancelled the prompt.
class BiometricFailure extends Failure {
  const BiometricFailure({required super.message, super.debugDetail});
}

/// Reading or writing secure storage failed.
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'No pudimos guardar tu sesion en este dispositivo.',
    super.debugDetail,
  });
}

/// The endpoint this feature needs does not exist on the server yet.
///
/// This is not a defensive catch-all — it is used deliberately, in exactly
/// one place, for password recovery. The QMS backend has `login-patient`,
/// `init-registration-patient` and `register-patient`, and NOTHING for
/// resetting a forgotten password. Rather than let the app fail with a raw
/// 404 or, worse, pretend the mail was sent, the data source returns this and
/// the screen says so plainly.
///
/// Delete this class the day those two endpoints ship.
class NotImplementedOnServerFailure extends Failure {
  const NotImplementedOnServerFailure({
    super.message =
        'La recuperacion de contrasena todavia no esta habilitada. '
        'Comunicate con la clinica para restablecerla.',
    super.debugDetail,
  });
}
