import 'package:dio/dio.dart';

import '../token_store.dart';

/// Attaches the session token to every outgoing request.
///
/// ## The important part: it sends the token TWICE, on purpose
///
/// The QMS backend authenticates from a **cookie**, not from a header. This is
/// `JwtValidator.recoverToken`, in full:
///
/// ```java
/// private String recoverToken(HttpServletRequest req) {
///   if (req.getCookies() != null) {
///     for (Cookie cookie : req.getCookies()) {
///       if ("jwt".equals(cookie.getName())) return cookie.getValue();
///     }
///   }
///   return null;
/// }
/// ```
///
/// It never looks at `Authorization`, even though `JwtConstants.JWT_HEADER`
/// declares that name. So there is a real hole in the mobile path:
/// `/auth/mobile/login-patient` hands a native client its token in an
/// `Authorization` response header, and then nothing on the server will accept
/// that token back in an `Authorization` request header.
///
/// The fix that needs no server change is this: send `Cookie: jwt=<token>`
/// ourselves. `httpOnly` and `Secure` are browser rules — Dio is not a
/// browser, and a cookie is just a header. That is what makes the app work
/// today.
///
/// `Authorization: Bearer <token>` goes out alongside it, and that is not
/// belt-and-braces for its own sake: the day someone adds three lines to
/// `recoverToken` to read the header, this app already works against it and
/// the cookie line can be deleted. Sending both costs one header.
///
/// If you are the person adding those three lines: delete [_alsoSendCookie]
/// and this comment, in that order.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStore);

  final TokenStore _tokenStore;

  /// The cookie name `JwtValidator` looks for.
  static const String _cookieName = 'jwt';

  /// Set to false once the server reads `Authorization`.
  static const bool _alsoSendCookie = true;

  /// Requests that must go out WITHOUT a token.
  ///
  /// Login especially: an expired token on a login call would make
  /// `JwtValidator` reject the request with 401 before `AuthController` ever
  /// runs, so a user whose session expired could never log back in. That is a
  /// genuinely nasty lockout, and it is caused by being helpful with headers.
  static const Set<String> _anonymousPaths = <String>{
    '/auth/mobile/login-patient',
    '/auth/login-patient',
    '/auth/init-registration-patient',
    '/auth/forgot-password',
    '/auth/reset-password',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_anonymousPaths.contains(options.path)) {
      return handler.next(options);
    }

    final String? token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      return handler.next(options);
    }

    options.headers['Authorization'] = 'Bearer $token';

    if (_alsoSendCookie) {
      // Merge rather than overwrite: if something else already put cookies on
      // this request, clobbering them would be a bug that only shows up later.
      final String existing = (options.headers['Cookie'] as String?) ?? '';
      final String jwtCookie = '$_cookieName=$token';
      options.headers['Cookie'] = existing.isEmpty
          ? jwtCookie
          : '$existing; $jwtCookie';
    }

    handler.next(options);
  }
}
