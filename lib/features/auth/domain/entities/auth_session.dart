import 'package:equatable/equatable.dart';

import 'auth_user.dart';

/// A live session: who is signed in, and the token that proves it.
///
/// The token is part of the entity rather than hidden in the data layer
/// because the router needs to know a session exists, and the interceptor
/// needs the token itself. Keeping them together means there is no way to
/// have one without the other — which is the bug where the app looks logged
/// in and every request comes back 401.
class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.token});

  final AuthUser user;

  /// The raw JWT. Never logged, never shown, never put in a URL.
  final String token;

  @override
  List<Object?> get props => <Object?>[user, token];

  /// Deliberately overridden so a stray `print(session)` in a debugging
  /// session cannot leak a bearer credential into the console.
  @override
  String toString() => 'AuthSession(${user.email}, token: <redacted>)';
}
