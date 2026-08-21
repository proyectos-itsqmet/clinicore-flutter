part of 'auth_bloc.dart';

/// Three states, and the third one is the one people forget.
enum AuthStatus {
  /// We have not finished reading storage yet.
  ///
  /// This exists so the app can hold a splash instead of flashing the login
  /// screen at a patient who IS signed in. Without it, every cold start shows
  /// login for a frame or two and then jumps — which reads as a bug and, worse,
  /// invites the patient to start typing.
  unknown,

  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  const AuthState._({required this.status, this.session});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AuthSession session)
    : this._(status: AuthStatus.authenticated, session: session);

  final AuthStatus status;

  /// Non-null exactly when [status] is [AuthStatus.authenticated].
  final AuthSession? session;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  @override
  List<Object?> get props => <Object?>[status, session];
}
