import 'package:dio/dio.dart';

import '../error/exceptions.dart';

/// Turns a [DioException] into one of this app's [AppException]s.
///
/// Called from a data source's `catch` block, not from an interceptor. An
/// interceptor that rejects with a foreign error type forces every call site
/// to unwrap `e.error as AppException`, which is indirection with no payoff —
/// a plain function is easier to read and easier to test.
///
/// The QMS backend answers every refusal through `Helper.getResponseMessage`,
/// which produces `{"message": "..."}`. Those strings are written for the
/// patient ("El usuario ya se encuentra registrado con esta cédula"), so they
/// are preferred over anything this app could invent. [_serverMessage] digs
/// that out, tolerating the one place the backend spells the key `Message`
/// with a capital M (`init-registration-patient`).
AppException mapDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    // Raised when Dio's own response transformer runs out of time — a huge or
    // malformed body. It is a timeout from the caller's point of view, so it
    // gets the same message rather than a fourth kind of error.
    case DioExceptionType.transformTimeout:
      return const NetworkException(
        message: 'La conexion tardo demasiado. Intenta de nuevo.',
      );

    case DioExceptionType.connectionError:
      return const NetworkException(
        message: 'No pudimos conectarnos. Revisa tu internet.',
      );

    case DioExceptionType.cancel:
      return const NetworkException(message: 'Peticion cancelada.');

    case DioExceptionType.badCertificate:
      return const NetworkException(
        message: 'El certificado del servidor no es valido.',
      );

    case DioExceptionType.unknown:
      return NetworkException(
        message: 'No pudimos conectarnos. Revisa tu internet.',
        // The real cause — usually a SocketException — stays reachable for
        // logs without ever reaching the screen.
        data: exception.error?.toString() ?? exception.message,
      );

    case DioExceptionType.badResponse:
      return _mapStatus(exception);
  }
}

AppException _mapStatus(DioException exception) {
  final Response<dynamic>? response = exception.response;
  final int status = response?.statusCode ?? 0;
  final Object? data = response?.data;
  final String? serverMessage = _serverMessage(data);

  if (status == 401 || status == 403) {
    return UnauthorizedException(
      message: serverMessage ?? 'Sesion invalida o inexistente.',
      statusCode: status,
      data: data,
    );
  }

  if (status >= 400 && status < 500) {
    return BadRequestException(
      message: serverMessage ?? 'No pudimos procesar la solicitud.',
      statusCode: status,
      data: data,
    );
  }

  return ServerException(
    message: serverMessage ?? 'El servicio no responde.',
    statusCode: status,
    data: data,
  );
}

/// Pulls the server's own message out of the body.
///
/// Handles the three shapes the QMS backend actually produces:
/// * `{"message": "..."}` — `Helper.getResponseMessage`, the common case
/// * `{"Message": "..."}` — `init-registration-patient`, capital M
/// * `{"error": "...", "message": "..."}` — the security entry point
String? _serverMessage(Object? data) {
  if (data is! Map) return null;
  for (final String key in <String>['message', 'Message', 'error']) {
    final Object? value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
