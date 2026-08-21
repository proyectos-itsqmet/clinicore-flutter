import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Request logging that never prints a credential.
///
/// Dio ships `LogInterceptor`, and it is not usable here: with
/// `requestBody: true` it prints the login body verbatim, which means every
/// patient's password ends up in the console, in CI output, and in whatever
/// crash reporter is attached to stdout. With `requestBody: false` it is
/// useless for debugging a 400.
///
/// So this one logs the shape and redacts the values: known-sensitive keys
/// become `***`, and the `Authorization` and `Cookie` headers are reduced to
/// their length. You can still see that a token was sent and roughly how big
/// it was, which is all a debugging session ever needs.
///
/// It is only installed in debug builds — see `AppConfig.enableNetworkLogs`.
class RedactingLogInterceptor extends Interceptor {
  const RedactingLogInterceptor();

  static const String _name = 'clinicore.http';

  /// Body keys whose values must never be printed.
  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'newPassword',
    'currentPassword',
    'otp',
    'token',
    'jwt',
    'ci',
  };

  /// Headers reduced to a length instead of a value.
  static const Set<String> _sensitiveHeaders = <String>{
    'authorization',
    'cookie',
    'set-cookie',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      '--> ${options.method} ${options.uri}\n'
      'headers: ${_redactHeaders(options.headers)}\n'
      'body: ${_redactBody(options.data)}',
      name: _name,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '<-- ${response.statusCode} ${response.requestOptions.uri}\n'
      'headers: ${_redactHeaders(response.headers.map)}\n'
      'body: ${_redactBody(response.data)}',
      name: _name,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '<-- ERROR ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri}\n'
      'body: ${_redactBody(err.response?.data)}',
      name: _name,
    );
    handler.next(err);
  }

  Map<String, Object?> _redactHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (!_sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry<String, Object?>(key, value);
      }
      final String raw = value is List ? value.join() : '$value';
      return MapEntry<String, Object?>(key, '<${raw.length} chars>');
    });
  }

  Object? _redactBody(Object? body) {
    if (body is Map) {
      return body.map((key, value) {
        final bool sensitive = _sensitiveKeys.contains('$key');
        return MapEntry<Object?, Object?>(
          key,
          sensitive ? '***' : _redactBody(value),
        );
      });
    }
    if (body is List) return body.map(_redactBody).toList();
    return body;
  }
}
